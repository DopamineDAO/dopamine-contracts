// SPDX-License-Identifier: BSD-3-Clause

/// @title Compound-style vote checkpointing for ERC-721

pragma solidity ^0.8.9;

import './ERC721.sol';

////////////////////////////////////////////////////////////////////////////////
///                              Custom Errors                               ///
////////////////////////////////////////////////////////////////////////////////
 
/// @notice Signature has expired and is no longer valid.
error ExpiredSignature();

/// @notice Block number being queried is invalid.
error InvalidBlock();

/// @notice Signature is invalid.
error InvalidSignature();

/// @notice Number does not fit in 32 bytes.
error InvalidUint32();

/// @title DθPΛM1NΞ ERC-721 voting contract.
/// @notice ERC-721 voting contract inspired by Nouns DAO and Compound.
abstract contract ERC721Checkpointable is ERC721 {

	/// @notice Marker for recording the voting power held for a given block.
    /// @dev Packs 4 checkpoints per storage slot, and assumes supply < 2^32.
	struct Checkpoint {
		uint32 fromBlock;
		uint32 votes;
	}

	/// @notice Maps addresses to their currently selected voting delegates.
    /// @dev A delegate of address(0) corresponds to self-delegation.
	mapping(address => address) internal _delegates;

	/// @notice A record of voting checkpoints for an address.
	mapping(address => Checkpoint[]) public checkpoints;

	/// @notice EIP-712 typehash used for voting delegation.
	bytes32 public constant DELEGATION_TYPEHASH =
		keccak256('Delegate(address delegator,address delegatee,uint256 nonce,uint256 expiry)');

    /// @notice `delegator` changes delegate from `fromDelegate` to `toDelegate`.
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice `delegate` votes change from `oldBalance` to `newBalance`.
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 oldBalance,
        uint256 newBalance
    );

    /// @notice Constructs a new ERC-721 voting contract.
	constructor(string memory name_, string memory symbol_, uint256 maxSupply_)
        ERC721(name_, symbol_, maxSupply_) {
    }

    /// @notice Returns the currently assigned delegate for `delegator`.
    /// @dev A value of address(0) indicates self-delegation.
    /// @param `delegator` The address of the delegator
    /// @return Address of the assigned delegate, if it exists, else address(0).
    function delegates(address delegator) public view returns (address) {
        address current = _delegates[delegator];
        return current == address(0) ? delegator : current;
    }

    /// @notice Delegate voting power of `msg.sender` to `delegatee`.
    /// @param delegatee Address to become delegator's delegatee.
    function delegate(address delegatee) public {
        _delegate(msg.sender, delegatee);
    }

    /// @notice Have `delegator` delegate to `delegatee` using EIP-712 signing.
    /// @param delegator The address which is performing delegation.
    /// @param delegatee The address being delegated to.
    /// @param expiry The timestamp at which this signature is set to expire.
    /// @param v Transaction signature recovery identifier.
    /// @param r Transaction signature output component #1.
    /// @param s Transaction signature output component #2.
    function delegateBySig(
        address delegator,
        address delegatee,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (block.timestamp > expiry) {
            revert ExpiredSignature();
        }
        address signatory;
        unchecked {
            signatory = ecrecover(
                _hashTypedData(keccak256(abi.encode(DELEGATION_TYPEHASH, delegator, delegatee, nonces[delegator]++, expiry))),
                v,
                r,
                s
            );
        }
        if (signatory == address(0) || signatory != delegator) {
            revert InvalidSignature();
        }
        _delegate(signatory, delegatee);
    }

    /// @notice Get the current number of votes allocated for address `voter`.
    /// @param voter The address being queried.
    /// @return The number of votes for address `voter`.
    function getCurrentVotes(address voter) external view returns (uint32) {
        uint256 numCheckpoints = checkpoints[voter].length;
        return numCheckpoints == 0 ?
            0 : checkpoints[voter][numCheckpoints - 1].votes;
    }

    /// @notice Get number of checkpoints registered by a voter `voter`.
    /// @param voter Address of the voter being queried.
    /// @return The number of checkpoints assigned to `voter`.
    function getNumCheckpoints(address voter) public view returns (uint256) {
        return checkpoints[voter].length;
    }

    /// @notice Get number of votes for `voter` at block number `blockNumber`.
    /// @param voter Address of the voter being queried.
    /// @param blockNumber Block number being queried.
    /// @return The uint32 voting weight of `voter` at `blockNumber`.
    function getPriorVotes(address voter, uint256 blockNumber) public view returns (uint32) {
        if (blockNumber >= block.number) {
            revert InvalidBlock();
        }

        uint256 numCheckpoints = checkpoints[voter].length;
        if (numCheckpoints == 0) {
            return 0;
        }

        // Check common case of `blockNumber` being ahead of latest checkpoint.
        if (checkpoints[voter][numCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[voter][numCheckpoints - 1].votes;
        }

        // Check case of `blockNumber` being behind first checkpoint (0 votes).
        if (checkpoints[voter][0].fromBlock > blockNumber) {
            return 0;
        }

        // Run binary search to find 1st checkpoint at or before `blockNumber`.
        uint256 lower = 0;
        uint256 upper = numCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[voter][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[voter][lower].votes;
    }

    /// @notice Delegate voting power of `delegator` to `delegatee`.
    /// @param delegator Address of the delegator
    /// @param delegatee Address of the delegatee
	function _delegate(address delegator, address delegatee) internal {
		if (delegatee == address(0)) delegatee = delegator;

		address currentDelegate = delegates(delegator);
		uint256 amount = balanceOf[delegator];

		_delegates[delegator] = delegatee;
		emit DelegateChanged(delegator, currentDelegate, delegatee);

		_transferDelegates(currentDelegate, delegatee, amount);
	}

    /// @notice Transfer `amount` voting power from `srcRep` to `dstRep`.
    /// @param srcRep The delegate whose votes are being transferred away from.
    /// @param dstRep The delegate who is being transferred additional votes.
    /// @param amount The number of votes being transferred.
	function _transferDelegates(
		address srcRep,
		address dstRep,
		uint256 amount
	) internal {
		if (srcRep != dstRep && amount > 0) {
			if (srcRep != address(0)) {
				(uint256 oldVotes, uint256 newVotes) = _writeCheckpoint(checkpoints[srcRep], _sub, amount);
				emit DelegateVotesChanged(srcRep, oldVotes, newVotes);
			}

			if (dstRep != address(0)) {
				(uint256 oldVotes, uint256 newVotes) = _writeCheckpoint(checkpoints[dstRep], _add, amount);
				emit DelegateVotesChanged(dstRep, oldVotes, newVotes);
			}
		}
	}

    /// @notice Adds a new checkpoint to `ckpts` by performing `op` of amount
    ///  `delta` on the last known checkpoint of `ckpts` (if it exists).
    /// @param ckpts Storage pointer to the Checkpoint array being modified
    /// @param op Function operation - either add or subtract
    /// @param delta Amount in voting units to be added or subtracted from.
	function _writeCheckpoint(
		Checkpoint[] storage ckpts,
		function(uint256, uint256) view returns (uint256) op,
		uint256 delta
	) private returns (uint256 oldVotes, uint256 newVotes) {
		uint256 numCheckpoints = ckpts.length;
		oldVotes = numCheckpoints == 0 ? 0 : ckpts[numCheckpoints - 1].votes;
		newVotes = op(oldVotes, delta);

		if ( // If latest checkpoint belonged to current block, just reassign.
             numCheckpoints > 0 && 
            ckpts[numCheckpoints - 1].fromBlock == block.number
        ) {
			ckpts[numCheckpoints - 1].votes = _safe32(newVotes);
		} else { // Otherwise, a new Checkpoint must be created.
			ckpts.push(Checkpoint({
				fromBlock: _safe32(block.number),
				votes: _safe32(newVotes)
			}));
		}
	}

    /// @notice Override pre-transfer hook to account for voting power transfer.
    /// @param from The address from which the NFT is being transferred.
    /// @param to The receiving address of the NFT.
    /// @param id The identifier of the NFT being transferred.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, id);
        _transferDelegates(delegates(from), delegates(to), 1);
    }


    /// @notice Safely downcasts a uint256 into a uint32.
	function _safe32(uint256 n) internal pure returns (uint32) {
        if (n > type(uint32).max) {
            revert InvalidUint32();
        }
		return uint32(n);
	}

	function _add(uint256 a, uint256 b) private pure returns (uint256) {
		return a + b;
	}

	function _sub(uint256 a, uint256 b) private pure returns (uint256) {
		return a - b;
	}

}
