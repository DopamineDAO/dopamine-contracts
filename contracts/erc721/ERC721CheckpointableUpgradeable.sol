// SPDX-License-Identifier: BSD-3-Clause

/// @title Vote checkpointing for an ERC-721 token

// LICENSE
// ERC721Checkpointable.sol uses and modifies part of Compound Lab's Comp.sol:
// https://github.com/compound-finance/compound-protocol/blob/ae4388e780a8d596d97619d9704a931a2752c2bc/contracts/Governance/Comp.sol
//
// Comp.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// With modifications by Nounders DAO.
//
// Additional conditions of BSD-3-Clause can be found here: https://opensource.org/licenses/BSD-3-Clause
//
// MODIFICATIONS
// Checkpointing logic from Comp.sol has been used with the following modifications:
// - `delegates` is renamed to `_delegates` and is set to private
// - `delegates` is a public function that uses the `_delegates` mapping look-up, but unlike
//   Comp.sol, returns the delegator's own address if there is no delegate.
//   This avoids the delegator needing to "delegate to self" with an additional transaction
// - `_transferTokens()` is renamed `_beforeTokenTransfer()` and adapted to hook into OpenZeppelin's ERC721 hooks.

pragma solidity ^0.8.9;

import './ERC721EnumerableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

// TODO: Add interface for checkpointable contract
abstract contract ERC721CheckpointableUpgradeable is Initializable, ERC721EnumerableUpgradeable, EIP712Upgradeable {
    /// @notice Defines decimals as per ERC-20 convention to make integrations with 3rd party governance platforms easier
    uint8 public constant decimals = 0;

    /// @notice A record of each accounts delegate
    mapping(address => address) private _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint32 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => Checkpoint[]) public checkpoints;

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function __ERC721Checkpointable_init(string memory name_) internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __EIP712_init_unchained(name_, "1");
        __ERC721Checkpointable_init_unchained(name_);
    }

    function __ERC721Checkpointable_init_unchained(string memory name_) internal initializer {
    }

	/**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return _safe32(checkpoints[account].length);
    }

    /**
     * @notice Overrides the standard `Comp.sol` delegates mapping to return
     * the delegator's own address if they haven't delegated.
     * This avoids having to delegate to oneself.
     */
    function delegates(address delegator) public view returns (address) {
        address current = _delegates[delegator];
        return current == address(0) ? delegator : current;
    }

    /**
     * @notice Adapted from `_transferTokens()` in `Comp.sol` to update delegate votes.
     * @dev hooks into OpenZeppelin's `ERC721._transfer`
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        /// @notice Differs from `_transferTokens()` to use `delegates` override method to simulate auto-delegation
        _transferDelegates(delegates(from), delegates(to), 1);
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        if (delegatee == address(0)) delegatee = msg.sender;
        _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= expiry, 'ERC721Checkpointable::delegateBySig: signature expired');
        address signatory = ECDSAUpgradeable.recover(
            _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        require(nonce == nonces[signatory]++, 'ERC721Checkpointable::delegateBySig: invalid nonce');
        _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint32) {
        uint256 nCheckpoints = checkpoints[account].length;
        return nCheckpoints == 0 ? 0 : checkpoints[account][nCheckpoints - 1].votes;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint32) {
        require(blockNumber < block.number, 'ERC721Checkpointable::getPriorVotes: not yet determined');

        uint256 nCheckpoints = checkpoints[account].length;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        if (delegatee == address(0)) delegatee = delegator;
        /// @notice differs from `_delegate()` in `Comp.sol` to use `delegates` override method to simulate auto-delegation
        address currentDelegate = delegates(delegator);
        uint256 amount = balanceOf(delegator);

        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _transferDelegates(currentDelegate, delegatee, amount);
    }

    function _transferDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) private {
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

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
		function(uint256, uint256) view returns (uint256) op,
		uint256 delta
    ) private returns (uint256 oldVotes, uint256 newVotes) {
		uint256 nCheckpoints = ckpts.length;
		oldVotes = nCheckpoints == 0 ? 0 : ckpts[nCheckpoints - 1].votes;
		newVotes = op(oldVotes, delta);

        if (nCheckpoints > 0 && ckpts[nCheckpoints - 1].fromBlock == block.number) {
            ckpts[nCheckpoints - 1].votes = _safe32(newVotes);
        } else {
			ckpts.push(Checkpoint({
				fromBlock: _safe32(block.number),
				votes: _safe32(newVotes)
			}));
        }

    }

    function _safe32(uint256 n) internal pure returns (uint32) {
        require(n < 2**32, "value does not fit within 32 bits");
        return uint32(n);
    }

	function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    uint256[10] private __gap;

}
