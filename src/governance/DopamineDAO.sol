// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import '../interfaces/IDopamineDAO.sol';
import '../errors.sol';
import './DopamineDAOStorage.sol';

////////////////////////////////////////////////////////////////////////////////
///                              Custom Errors                               ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine DAO Implementation Contract
/// @notice Compound Governor Bravo fork built for DθPΛM1NΞ NFTs.
contract DopamineDAO is UUPSUpgradeable, DopamineDAOStorageV1, IDopamineDAO {

	////////////////////////////////////////////////////////////////////////////
	///						  Governance Constants                           ///
	////////////////////////////////////////////////////////////////////////////

    /// @notice Min number & max % of NFTs required for making a proposal.
	uint32 public constant MIN_PROPOSAL_THRESHOLD = 1; // 1 NFT
	uint32 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000; // 10%

    /// @notice Min & max time for which proposal votes are valid, in blocks.
	uint32 public constant MIN_VOTING_PERIOD = 6400; // ~1 day
	uint32 public constant MAX_VOTING_PERIOD = 134000; // ~3 Weeks

    /// @notice Min & max wait time before proposal voting opens, in blocks.
	uint32 public constant MIN_VOTING_DELAY = 1; // Next block
	uint32 public constant MAX_VOTING_DELAY = 45000; // ~1 Week

    /// @notice Min & max quorum thresholds, in bips.
	uint32 public constant MIN_QUORUM_THRESHOLD_BPS = 200; // 2%
	uint32 public constant MAX_QUORUM_THRESHOLD_BPS = 2_000; // 20%

    /// @notice Max # of allowed operations for a single proposal.
	uint256 public constant PROPOSAL_MAX_OPERATIONS = 10;
	
	////////////////////////////////////////////////////////////////////////////
    ///                       Miscellaneous Constants                        ///
	////////////////////////////////////////////////////////////////////////////

	bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(address voter,uint256 proposalId,uint8 support)");

    /// @notice EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _RARITY_SOCIETY_DAO_INTERFACE_ID = 0x8a5da15c;

    /// @notice EIP-712 immutables for signing messages.
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    /// @notice Modifier to restrict calls to admin only.
	modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
		_;
	}

    /// @notice Creates the DAO contract without any storage slots filled.
    /// @param proxy Address of the proxy, for EIP-712 signing verification.
    /// @dev Chain ID and domain separator are assigned here as immutables.
    constructor(
        address proxy
    ) {
        // Prevent implementation re-initialization.
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("Dopamine DAO")),
                keccak256(bytes("1")),
                block.chainid,
                proxy
            )
        );
    }

    /// @notice Initializes the Dopamine DAO governance contract.
    /// @param timelock_ Timelock address, which controls proposal execution.
    /// @param token_ Governance token, from which voting weights are derived.
    /// @param vetoer_ Address with temporary veto power (revoked later on).
    /// @param votingPeriod_ Time a proposal is up for voting, in blocks.
    /// @param votingDelay_ Time before opening proposal for voting, in blocks.
    /// @param proposalThreshold_ Number of NFTs required to submit a proposal.
    /// @param quorumThresholdBPS_ Threshold required for proposal to pass, in bips.
	function initialize(
		address timelock_,
		address token_,
		address vetoer_,
		uint32 votingPeriod_,
		uint32 votingDelay_,
		uint32 proposalThreshold_,
        uint32 quorumThresholdBPS_
    ) onlyProxy public {
        if (address(token) != address(0)) {
            revert AlreadyInitialized();
        }

        admin = msg.sender;
		vetoer = vetoer_;
        token = IDopamineDAOToken(token_);
		timelock = ITimelock(timelock_);

        setVotingPeriod(votingPeriod_);
		setVotingDelay(votingDelay_);
		setQuorumThresholdBPS(quorumThresholdBPS_);
		setProposalThreshold(proposalThreshold_);
	}

    /// @notice Create a new proposal.
    /// @dev Proposer voting weight determined by delegated and held gov tokens.
    /// @param targets Target addresses for calls being executed.
    /// @param values Eth values to send for the execution calls.
    /// @param signatures Function signatures for each call.
    /// @param calldatas Calldata that is passed with each execution call.
    /// @param description Description of the overall proposal.
    /// @return Proposal identifier of the created proposal.
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint32) {
        if (token.getPriorVotes(msg.sender, block.number - 1) < proposalThreshold) {
            revert InsufficientVotingPower();
        }

        if (targets.length  != values.length || targets.length != signatures.length || targets.length != calldatas.length) {
            revert ArityMismatch();
        }

        if (targets.length == 0 || targets.length > PROPOSAL_MAX_OPERATIONS) {
            revert InvalidActionCount();
        }

        ProposalState state = state();
        if (
            proposal.startBlock != 0 && 
                (
                    state == ProposalState.Pending ||
                    state == ProposalState.Active ||
                    state == ProposalState.Succeeded ||
                    state == ProposalState.Queued
                )
        ) {
            revert UnsettledProposal();
        }

        uint32 quorumThreshold = uint32(max(
            1, bps2Uint(quorumThresholdBPS, token.totalSupply())
        ));

        proposal.eta = 0;
        proposal.proposer = msg.sender;
        proposal.id = ++proposalId;
        proposal.quorumThreshold = quorumThreshold;
        proposal.startBlock = uint32(block.number) + votingDelay;
        proposal.endBlock = proposal.startBlock + votingPeriod;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstainVotes = 0;
        proposal.vetoed = false;
        proposal.canceled = false;
        proposal.executed = false;
        proposal.targets = targets;
        proposal.values = values;
        proposal.signatures = signatures;
        proposal.calldatas = calldatas;

        emit ProposalCreated(
            proposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            proposal.startBlock,
            proposal.endBlock,
            proposal.quorumThreshold,
            description
        );

        return proposal.id;
    }

    /// @notice Queues the current proposal if successfully passed.
    function queue() public {
        if (state() != ProposalState.Succeeded) {
            revert UnpassedProposal();
        }
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    /// @notice Queues a proposal's execution call through the Timelock.
    /// @param target Target address for which the call will be executed.
    /// @param value Eth value to send with the call.
    /// @param signature Function signature associated with the call.
    /// @param data Function calldata associated with the call.
    /// @param eta Timestamp after which the call may be executed.
    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        if (timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta)))) {
            revert DuplicateTransaction();
        }
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /// @notice Executes the current proposal if queued and past timelock delay.
    function execute() public {
        if (state() != ProposalState.Queued) {
            revert UnqueuedProposal();
        }
        proposal.executed = true;
        unchecked {
            for (uint256 i = 0; i < proposal.targets.length; i++) {
                timelock.executeTransaction(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.signatures[i],
                    proposal.calldatas[i],
                    proposal.eta
                );
            }
        }
        emit ProposalExecuted(proposal.id);
    }

    /// @notice Cancel the current proposal if not yet settled.
    function cancel() public {
        if (proposal.executed) {
            revert AlreadySettled();
        }
        if (msg.sender != proposal.proposer) {
            revert ProposerOnly();
        }
        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalCanceled(proposal.id);
    }

    /// @notice Veto the proposal if not yet settled.
    /// @dev Veto power meant to be revoked once gov tokens evenly distributed.
    function veto() public {
        if (vetoer == address(0)) {
            revert VetoPowerRevoked();
        }
        if (proposal.executed) {
            revert AlreadySettled();
        }
        if (msg.sender != vetoer) {
            revert VetoerOnly();
        }
        proposal.vetoed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalVetoed(proposal.id);
    }

    /// @notice Get the actions of the current proposal.
    function getActions() public view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) {
        return (
            proposal.targets,
            proposal.values,
            proposal.signatures,
            proposal.calldatas
        );
    }

    /// @notice Get the current proposal's state.
    /// @dev Until the first proposal is created, erroneously returns Defeated.
    /// @return The current proposal's state.
	function state() public view override returns (ProposalState) {
		if (proposal.vetoed) {
			return ProposalState.Vetoed;
		} else if (proposal.canceled) {
			return ProposalState.Canceled;
		} else if (block.number < proposal.startBlock) {
			return ProposalState.Pending;
		} else if (block.number <= proposal.endBlock) {
			return ProposalState.Active;
		} else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < proposal.quorumThreshold) {
			return ProposalState.Defeated;
		} else if (proposal.eta == 0) {
			return ProposalState.Succeeded;
		} else if (proposal.executed) {
			return ProposalState.Executed;
		} else if (block.timestamp > proposal.eta + timelock.GRACE_PERIOD()) {
			return ProposalState.Expired;
		} else {
			return ProposalState.Queued;
		}
	}

    /// @notice Cast vote of type `support` for the current proposal.
    /// @param support The vote type: 0 = against, 1 = support, 2 = abstain
	function castVote(uint8 support) public override {
         _castVote(msg.sender, support);
	}

    /// @notice Cast EIP-712 vote by sig of `voter` for the current proposal.
    /// @dev nonces are not used as voting functions prevent replays already.
    /// @param voter The address of the voter whose signature is being used.
    /// @param support The vote type: 0 = against, 1 = support, 2 = abstain
    /// @param v Transaction signature recovery identifier.
    /// @param r Transaction signature output component #1.
    /// @param s Transaction signature output component #2.
	function castVoteBySig(
        address voter,
		uint8 support,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		address signatory = ecrecover(
			_hashTypedData(keccak256(abi.encode(VOTE_TYPEHASH, voter, proposalId, support))),
			v,
			r,
			s
		);
        if (signatory == address(0) || signatory != voter) {
            revert InvalidSignature();
        }
        _castVote(signatory, support);
	}

    /// @notice Sets a new proposal voting timeframe, `newVotingPeriod`.
    /// @param newVotingPeriod The new voting period to set, in blocks.
	function setVotingPeriod(uint32 newVotingPeriod) public override onlyAdmin {
        if (newVotingPeriod < MIN_VOTING_PERIOD || newVotingPeriod > MAX_VOTING_PERIOD) {
            revert InvalidVotingPeriod();
        }
		votingPeriod = newVotingPeriod;
		emit VotingPeriodSet(votingPeriod);
	}

    /// @notice Sets a new proposal voting delay, `newVotingDelay`.
    /// @dev `votingDelay` is how long to wait before proposal voting opens.
    /// @param newVotingDelay The new voting delay to set, in blocks.
	function setVotingDelay(uint32 newVotingDelay) public override onlyAdmin {
        if (newVotingDelay < MIN_VOTING_DELAY || newVotingDelay > MAX_VOTING_DELAY) {
            revert InvalidVotingDelay();
        }
		votingDelay = newVotingDelay;
		emit VotingDelaySet(votingDelay);
	}

    /// @notice Sets a new gov token proposal threshold, `newProposalThreshold`.
    /// @param newProposalThreshold The new proposal threshold to be set.
	function setProposalThreshold(uint32 newProposalThreshold) public override onlyAdmin {
        if (newProposalThreshold < MIN_PROPOSAL_THRESHOLD || newProposalThreshold > MAX_PROPOSAL_THRESHOLD()) {
            revert InvalidProposalThreshold();
        }
		proposalThreshold = newProposalThreshold;
		emit ProposalThresholdSet(proposalThreshold);
	}


    /// @notice Sets a new quorum voting threshold.
    /// @param newQuorumThresholdBPS The new quorum voting threshold, in bips.
	function setQuorumThresholdBPS(uint32 newQuorumThresholdBPS) public override onlyAdmin {
        if (newQuorumThresholdBPS < MIN_QUORUM_THRESHOLD_BPS || newQuorumThresholdBPS > MAX_QUORUM_THRESHOLD_BPS) {
            revert InvalidQuorumThreshold();
        }
		quorumThresholdBPS = newQuorumThresholdBPS;
		emit QuorumThresholdBPSSet(quorumThresholdBPS);
	}


    /// @notice Sets a new pending admin `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
	function setPendingAdmin(address newPendingAdmin) public override onlyAdmin {
		pendingAdmin = newPendingAdmin;
		emit NewPendingAdmin(pendingAdmin);
	}

    /// @notice Sets a new vetoer `newVetoer`, which can cancel proposals.
    /// @dev Veto power will be revoked upon sufficient gov token distribution.
    /// @param newVetoer The new vetoer address.
    function setVetoer(address newVetoer) public {
        if (msg.sender != vetoer) {
            revert VetoerOnly();
        }
        vetoer = newVetoer;
        emit NewVetoer(vetoer);
    }

    /// @notice Convert the current `pendingAdmin` to the new `admin`.
	function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

		emit NewAdmin(admin, pendingAdmin);
		admin = pendingAdmin;
        pendingAdmin = address(0);
	}

    /// @notice Return the maxproposal threshold, based on gov token supply.
    /// @return The maximum allowed proposal threshold, in number of gov tokens.
	function MAX_PROPOSAL_THRESHOLD() public view returns (uint32) {
		return uint32(max(MIN_PROPOSAL_THRESHOLD, bps2Uint(MAX_PROPOSAL_THRESHOLD_BPS, token.totalSupply())));
	}

    /// @notice Checks if interface of identifier `interfaceId` is supported.
    /// @param interfaceId Interface's ERC-165 identifier
    /// @return `true` if `interfaceId` is supported, `false` otherwise.
	function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
		return 
            interfaceId == _ERC165_INTERFACE_ID ||
            interfaceId == _RARITY_SOCIETY_DAO_INTERFACE_ID;
	}

    /// @notice Casts a `support` vote as `voter` for the current proposal.
    /// @param voter The address of the voter whose vote is being cast.
    /// @param support The vote type: 0 = against, 1 = support, 2 = abstain
    /// @return The number of votes (gov tokens delegated to / held by voter).
	function _castVote(
		address voter,
		uint8 support
	) internal returns (uint32) {
        if (state() != ProposalState.Active) {
            revert InactiveProposal();
        }
        if (support > 2) {
            revert InvalidVote();
        }

		Receipt storage receipt = receipts[voter];
        if (receipt.id == proposal.id) {
            revert AlreadyVoted();
        }

		uint32 votes = token.getPriorVotes(voter, proposal.startBlock - votingDelay);
		if (support == 0) {
			proposal.againstVotes = proposal.againstVotes + votes;
		} else if (support == 1) {
			proposal.forVotes = proposal.forVotes + votes;
		} else {
			proposal.abstainVotes = proposal.abstainVotes + votes;
		}

		receipt.id = proposalId;
		receipt.support = support;
		receipt.votes = votes;

		emit VoteCast(voter, proposal.id, support, votes);
		return votes;
	}

    /// @notice Performs authorization check for UUPS upgrades.
    function _authorizeUpgrade(address) internal override {
        if (msg.sender != admin && msg.sender != vetoer) {
            revert UnauthorizedUpgrade();
        }
    }

	/// @notice Generates an EIP-712 Dopamine DAO domain separator.
    /// @dev See https://eips.ethereum.org/EIPS/eip-712 for details.
    /// @return A 256-bit domain separator.
    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("Dopamine DAO")),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

	/// @notice Returns an EIP-712 encoding of structured data `structHash`.
    /// @param structHash The structured data to be encoded and signed.
    /// @return A bytestring suitable for signing in accordance to EIP-712.
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    /// @notice Returns the domain separator tied to the contract.
    /// @dev Recreated if chain id changes, otherwise cached value is used.
    /// @return 256-bit domain separator tied to this contract.
    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator();
        }
    }

    /// @notice Converts bips `bps` and number `number` to an integer.
    /// @param bps Number of basis points (1 BPS = 0.01%).
    /// @param number Decimal number being converted.
	function bps2Uint(uint256 bps, uint256 number) internal pure returns (uint256) {
		return (number * bps) / 10000;
	}

    /// @notice Returns the max between `a` and `b`.
	function max(uint256 a, uint256 b) internal pure returns (uint256) {
		return a >= b ? a : b;
	}

}
