// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// This file is under the copyright license: Copyright 2020 Compound Labs, Inc.
/// 
/// DopamineDAO.sol is a modification of Nouns DAO's NounsDAOLogicV1.sol:
/// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/governance/NounsDAOLogicV1.sol
///
/// Copyright licensing is under the BSD-3-Clause license, as the above contract
/// is a rework of Compound Lab's GovernorBravoDelegate.sol (of same license).
/// 
/// The following major changes were made from the original Nouns DAO contract:
/// - Proxy was changed from a modified Governor Bravo Delegator to a UUPS Proxy
/// - Only 1 proposal may be operated at a time (as opposed to 1 per proposer)
/// - Proposal thresholds use fixed number floors (n NFTs), BPS-based ceilings
/// - Voter receipts were removed in favor of event-based off-chain storage
/// - Most `Proposal` struct fields were changed to uint32 for tighter packing
/// - Global proposal id uses a uint32 instead of a uint256
/// - Bakes in EIP-712 data structures as immutables for more efficient caching
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../errors.sol";
import {IDopamineDAOToken} from "../interfaces/IDopamineDAOToken.sol";
import {ITimelock} from "../interfaces/ITimelock.sol";
import {IDopamineDAO} from "../interfaces/IDopamineDAO.sol";
import {DopamineDAOStorage} from "./DopamineDAOStorage.sol";

/// @title Dopamine DAO Implementation Contract
/// @notice The DopamineDAO contract is a Governor Bravo variant originally 
///  forked from Nouns DAO, constrained to support only one proposal at a time,
///  and modified to be integrated with UUPS proxies for easier upgrades. Like 
///  Governor Bravo, governance token holders may make proposals and vote for 
///  them based on their delegated voting weights. In the Dopamine DAO model,
///  governance tokens are ERC-721s  with a capped supply (Dopamine passes).
/// @dev It is intended for the admin to be configured as the  Timelock, and the
///  vetoer to initially be configured as the team multi-sig (revoked later).
contract DopamineDAO is UUPSUpgradeable, DopamineDAOStorage, IDopamineDAO {

    /// @notice The lowest settable threshold for proposals, in number of NFTs.
	uint256 public constant MIN_PROPOSAL_THRESHOLD = 1;

    /// @notice The max settable threshold for proposals, in supply % (bips).
	uint256 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000; // 10%

    /// @notice The minimum settable time in blocks proposals can be voted on.
	uint256 public constant MIN_VOTING_PERIOD = 6400; // ~1 day

    /// @notice The maximum settable time in blocks proposals can be voted on.
	uint256 public constant MAX_VOTING_PERIOD = 134000; // ~3 Weeks

    /// @notice The minimum settable wait time in blocks for starting proposals.
	uint256 public constant MIN_VOTING_DELAY = 1; // Next block

    /// @notice The maximum settable wait time in blocks for starting proposals.
	uint256 public constant MAX_VOTING_DELAY = 45000; // ~1 Week

    /// @notice The minimum quorum threshold in bips settable for proposals.
	uint256 public constant MIN_QUORUM_THRESHOLD_BPS = 200; // 2%

    /// @notice The maximum quorum threshold in bips settable for proposals.
	uint256 public constant MAX_QUORUM_THRESHOLD_BPS = 2_000; // 20%

    /// @notice The maximum number of allowed executions for a single proposal.
	uint256 public constant PROPOSAL_MAX_OPERATIONS = 10;
	
    /// @notice The typehash used for EIP-712 voting (see `castVoteBySig`).
	bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(address voter,uint256 proposalId,uint8 support)");

    // EIP-712 immutables for signing messages.
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    // EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _RARITY_SOCIETY_DAO_INTERFACE_ID = 0x8a5da15c;

    /// @notice This modifier restrict calls to only the admin.
	modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
		_;
	}

    /// @notice Instantiates the Dopamine DAO implementation contract.
    /// @param proxy Address of the proxy to be linked to the contract via UUPS.
    /// @dev The reason a constructor is used here despite this needing to be
    ///  initialized via a UUPS proxy is so that EIP-712 signing can be built 
    ///  off of proxy immutables (the proxy domain separator and chain ID).
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

    /// @inheritdoc IDopamineDAO
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        if (
            token.priorVotes(msg.sender, block.number - 1) < proposalThreshold) 
        {
            revert VotingPowerInsufficient();
        }

        if (
            targets.length != values.length     || 
            targets.length != signatures.length || 
            targets.length != calldatas.length
        ) {
            revert ArityMismatch();
        }

        if (targets.length == 0 || targets.length > PROPOSAL_MAX_OPERATIONS) {
            revert ProposalActionCountInvalid();
        }

        ProposalState proposalState = state();
        if (
            proposal.startBlock != 0 && 
                (
                    proposalState == ProposalState.Pending ||
                    proposalState == ProposalState.Active ||
                    proposalState == ProposalState.Succeeded ||
                    proposalState == ProposalState.Queued
                )
        ) {
            revert ProposalUnsettled();
        }

        proposalId += 1;

        proposal.eta = 0;
        proposal.proposer = msg.sender;
        proposal.quorumThreshold = uint32(
            max(1, bps2Uint(quorumThresholdBPS, token.totalSupply()))
        );
        proposal.startBlock = uint32(block.number) + uint32(votingDelay);
        proposal.endBlock = proposal.startBlock + uint32(votingPeriod);
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
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            proposal.startBlock,
            proposal.endBlock,
            description
        );

        return proposalId;
    }

    /// @inheritdoc IDopamineDAO
    function queue(uint256 id) public {
        if (id != proposalId) {
            revert ProposalInactive();
        }
        if (state() != ProposalState.Succeeded) {
            revert ProposalUnpassed();
        }
        uint256 eta = block.timestamp + timelock.timelockDelay();
        uint256 numTargets = proposal.targets.length;
        for (uint256 i = 0; i < numTargets; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(id, proposal.eta);
    }

    /// @inheritdoc IDopamineDAO
    function execute(uint256 id) public {
        if (id != proposalId) {
            revert ProposalInactive();
        }
        if (state() != ProposalState.Queued) {
            revert ProposalNotYetQueued();
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
        emit ProposalExecuted(id);
    }

    /// @inheritdoc IDopamineDAO
    function cancel(uint256 id) public {
        if (id != proposalId) {
            revert ProposalInactive();
        }
        if (proposal.executed) {
            revert ProposalAlreadySettled();
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
        emit ProposalCanceled(id);
    }


    /// @inheritdoc IDopamineDAO
    function veto() external {
        if (vetoer == address(0)) {
            revert VetoPowerRevoked();
        }
        if (proposal.executed) {
            revert ProposalAlreadySettled();
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
        emit ProposalVetoed(proposalId);
    }

    /// @inheritdoc IDopamineDAO
	function castVote(uint256 id, uint8 support) external {
		 emit VoteCast(
             msg.sender,
             id,
             support,
             _castVote(id, msg.sender, support),
             ""
         );
	}

    /// @inheritdoc IDopamineDAO
	function castVoteWithReason(
        uint256 id,
        uint8 support,
        string calldata reason
    ) 
    external 
    {
		 emit VoteCast(
             msg.sender,
             id,
             support,
             _castVote(id, msg.sender, support),
             reason
         );
	}

    /// @inheritdoc IDopamineDAO
	function castVoteBySig(
        uint256 id,
        address voter,
		uint8 support,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		address signatory = ecrecover(
			_hashTypedData(
                keccak256(abi.encode(VOTE_TYPEHASH, voter, id, support))
            ),
			v,
			r,
			s
		);
        if (signatory == address(0) || signatory != voter) {
            revert SignatureInvalid();
        }
		emit VoteCast(
            signatory,
            id,
            support,
            _castVote(id, signatory, support),
            ""
        );
	}

    /// @notice Initializes the Dopamine DAO governance contract.
    /// @dev This function may only be called via a proxy contract (e.g. UUPS).
    /// @param timelock_ Timelock address, which controls proposal execution.
    /// @param token_ Governance token, from which voting weights are derived.
    /// @param vetoer_ Address with temporary veto power (revoked later on).
    /// @param votingPeriod_ Time a proposal is up for voting, in blocks.
    /// @param votingDelay_ Time before opening proposal for voting, in blocks.
    /// @param proposalThreshold_ Number of NFTs required to submit a proposal.
    /// @param quorumThresholdBPS_ Supply % (bips) needed to pass a proposal.
	function initialize(
		address timelock_,
		address token_,
		address vetoer_,
		uint256 votingPeriod_,
		uint256 votingDelay_,
		uint256 proposalThreshold_,
        uint256 quorumThresholdBPS_
    ) onlyProxy public {
        if (address(token) != address(0)) {
            revert ContractAlreadyInitialized();
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

    /// @inheritdoc IDopamineDAO
	function maxProposalThreshold() public view returns (uint256) {
		return max(
            MIN_PROPOSAL_THRESHOLD,
            bps2Uint(MAX_PROPOSAL_THRESHOLD_BPS, token.totalSupply())
        );
	}

    /// @inheritdoc IDopamineDAO
    /// @dev Until the first proposal creation, this will return "Defeated".
	function state() public view override returns (ProposalState) {
		if (proposal.vetoed) {
			return ProposalState.Vetoed;
		} else if (proposal.canceled) {
			return ProposalState.Canceled;
		} else if (block.number < proposal.startBlock) {
			return ProposalState.Pending;
		} else if (block.number <= proposal.endBlock) {
			return ProposalState.Active;
		} else if (
            proposal.forVotes <= proposal.againstVotes || 
            proposal.forVotes < proposal.quorumThreshold
        ) {
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

    /// @inheritdoc IDopamineDAO
    function actions() external view returns (
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

    /// @inheritdoc IDopamineDAO
	function setVotingDelay(uint256 newVotingDelay) public override onlyAdmin {
        if (
            newVotingDelay < MIN_VOTING_DELAY || 
            newVotingDelay > MAX_VOTING_DELAY
        ) 
        {
            revert ProposalVotingDelayInvalid();
        }
		votingDelay = newVotingDelay;
		emit VotingDelaySet(votingDelay);
	}

    /// @inheritdoc IDopamineDAO
	function setVotingPeriod(uint256 newVotingPeriod)
        public 
        override 
        onlyAdmin 
    {
        if (
            newVotingPeriod < MIN_VOTING_PERIOD || 
            newVotingPeriod > MAX_VOTING_PERIOD
        ) 
        {
            revert ProposalVotingPeriodInvalid();
        }
		votingPeriod = newVotingPeriod;
		emit VotingPeriodSet(votingPeriod);
	}


    /// @inheritdoc IDopamineDAO
	function setProposalThreshold(uint256 newProposalThreshold) 
        public 
        override 
        onlyAdmin 
    {
        if (
            newProposalThreshold < MIN_PROPOSAL_THRESHOLD || 
            newProposalThreshold > maxProposalThreshold()
        ) 
        {
            revert ProposalThresholdInvalid();
        }
		proposalThreshold = newProposalThreshold;
		emit ProposalThresholdSet(proposalThreshold);
	}

    /// @inheritdoc IDopamineDAO
	function setQuorumThresholdBPS(uint256 newQuorumThresholdBPS) 
        public 
        override 
        onlyAdmin 
    {
        if (
            newQuorumThresholdBPS < MIN_QUORUM_THRESHOLD_BPS ||
            newQuorumThresholdBPS > MAX_QUORUM_THRESHOLD_BPS
        ) 
        {
            revert ProposalQuorumThresholdInvalid();
        }
		quorumThresholdBPS = newQuorumThresholdBPS;
		emit QuorumThresholdBPSSet(quorumThresholdBPS);
	}

    /// @inheritdoc IDopamineDAO
    function setVetoer(address newVetoer) public {
        if (msg.sender != vetoer) {
            revert VetoerOnly();
        }
        emit VetoerChanged(vetoer, newVetoer);
        vetoer = newVetoer;
    }

    /// @inheritdoc IDopamineDAO
	function setPendingAdmin(address newPendingAdmin) 
        public 
        override 
        onlyAdmin 
    {
		pendingAdmin = newPendingAdmin;
		emit PendingAdminSet(pendingAdmin);
	}

    /// @inheritdoc IDopamineDAO
	function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

		emit AdminChanged(admin, pendingAdmin);
		admin = pendingAdmin;
        pendingAdmin = address(0);
	}

    /// @notice Queues a current proposal's execution call through the Timelock.
    /// @param target Target address for which the call will be executed.
    /// @param value Eth value in wei  to send with the call.
    /// @param signature Function signature associated with the call.
    /// @param data Function calldata associated with the call.
    /// @param eta Timestamp in seconds after which the call may be executed.
    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        if (
            timelock.queuedTransactions(
                keccak256(abi.encode(target, value, signature, data, eta))
            )
        ) 
        {
            revert TransactionAlreadyQueued();
        }
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /// @notice Casts a `support` vote as `voter` for the current proposal.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    /// @param voter The address of the voter whose vote is being cast.
    /// @param support The vote type: 0 = against, 1 = for, 2 = abstain
    /// @return The number of votes (total number of NFTs delegated to voter).
	function _castVote(
        uint256 id,
		address voter,
		uint8 support
	) internal returns (uint256) {
        if (id != proposalId || state() != ProposalState.Active) {
            revert ProposalInactive();
        }
        if (support > 2) {
            revert VoteInvalid();
        }

        if (_lastVotedProposal[voter] == id) {
            revert VoteAlreadyCast();
        }

		uint32 votes = token.priorVotes(
            voter,
            proposal.startBlock - votingDelay
        );
		if (support == 0) {
			proposal.againstVotes = proposal.againstVotes + votes;
		} else if (support == 1) {
			proposal.forVotes = proposal.forVotes + votes;
		} else {
			proposal.abstainVotes = proposal.abstainVotes + votes;
		}

        _lastVotedProposal[voter] = id;

		return uint256(votes);
	}

    /// @notice Performs an authorization check for UUPS upgrades.
    /// @dev This function ensures only the admin & vetoer can upgrade the DAO.
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != admin && msg.sender != vetoer) {
            revert UpgradeUnauthorized();
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
    function _hashTypedData(bytes32 structHash) 
        internal 
        view 
        returns (bytes32) 
    {
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), structHash)
        );
    }

    /// @notice Returns the domain separator tied to the contract.
    /// @dev Recreated if chain id changes, otherwise a cached value is used.
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
	function bps2Uint(uint256 bps, uint256 number) 
        private 
        pure 
        returns (uint256) 
    {
		return (number * bps) / 10000;
	}

    /// @notice Returns the max between uints `a` and `b`.
	function max(uint256 a, uint256 b) private pure returns (uint256) {
		return a >= b ? a : b;
	}

}
