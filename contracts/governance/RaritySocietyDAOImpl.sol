pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import '../interfaces/IRaritySocietyDAO.sol';
import './RaritySocietyDAOStorage.sol';

contract RaritySocietyDAOImpl is RaritySocietyDAOStorageV1, IRaritySocietyDAO, ERC165 {

	uint256 public constant MIN_PROPOSAL_THRESHOLD = 1;

	uint256 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000; // 10%

	uint public constant MIN_VOTING_PERIOD = 6400; // 1 day

	uint public constant MAX_VOTING_PERIOD = 134000; // 3 Weeks

	uint256 public constant MIN_VOTING_DELAY = 1; 

	uint256 public constant MAX_VOTING_DELAY = 45000; // 1 Week

	uint256 public constant MIN_QUORUM_VOTES_BPS = 200; // 2%

	uint256 public constant MAX_QUORUM_VOTES_BPS = 2_000; // 20%

	uint256 public constant PROPOSAL_MAX_OPERATIONS = 10;

	bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    // keccak256(bytes("Rarity Society DAO"));
    bytes32 private constant _HASHED_NAME = 0x9DA14928BDE692BAFF0A25899816D2C3150D9FBAE1906909A24F755D610DDD03;

    // keccak256(bytes("1"));
    bytes32 private constant _HASHED_VERSION = 0xC89EFDAA54C0F20C7ADF612882DF0950F5A951637E0307CDCB4C672F298B8BC6;

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8B73C3C69BB8FE3D512ECC4CF759CC79239F7B179B0FFACAA9A75D522B39400F;

    bytes32 private _DOMAIN_SEPARATOR;


	modifier onlyAdmin() {
		require(msg.sender == admin, "admin only");
		_;
	}

	modifier onlyPendingAdmin() {
		require(msg.sender == pendingAdmin, "pending admin only");
		_;
	}

	function initialize(
		address timelock_,
		address token_,
		address vetoer_,
		uint256 votingPeriod_,
		uint256 votingDelay_,
		uint256 proposalThreshold_,
		uint256 quorumVotesBPS_
	) public onlyAdmin {
		require(address(timelock) == address(0), 'initializable only once');
        require(token_ != address(0), 'invalid governance token address');
        require(timelock_ != address(0), 'invalid timelock address');
        require(
            votingPeriod_ >= MIN_VOTING_PERIOD && votingPeriod_ <= MAX_VOTING_PERIOD,
            'invalid voting period'
        );
        require(
            votingDelay_ >= MIN_VOTING_DELAY && votingDelay_ <= MAX_VOTING_DELAY,
            'invalid voting delay'
        );
        require(
            quorumVotesBPS_ >= MIN_QUORUM_VOTES_BPS && quorumVotesBPS_ <= MAX_QUORUM_VOTES_BPS,
            'invalid quorum votes threshold'
        );

        emit VotingPeriodSet(votingPeriod, votingPeriod_);
        emit VotingDelaySet(votingDelay, votingDelay_);
        emit ProposalThresholdSet(proposalThreshold, proposalThreshold_);
        emit QuorumVotesBPSSet(quorumVotesBPS, quorumVotesBPS_);

        token = IRaritySocietyDAOToken(token_);
		timelock = ITimelock(timelock_);
		vetoer = vetoer_;
		votingPeriod = votingPeriod_;
		votingDelay = votingDelay_;
		proposalThreshold = proposalThreshold_;
		quorumVotesBPS = quorumVotesBPS_;

        _DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);

        require(
            proposalThreshold_ >= MIN_PROPOSAL_THRESHOLD && proposalThreshold_ <= maxProposalThreshold(),
            'invalid proposal threshold'
        );

	}

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            token.getPriorVotes(msg.sender, block.number - 1) >= proposalThreshold,
            'proposer votes below proposal threshold'
        );
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
            'proposal function arity mismatch'
        );
        require(targets.length != 0, 'actions not provided');
        require(targets.length <= PROPOSAL_MAX_OPERATIONS, 'too many actions');

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState latestProposalState = state(latestProposalId);
            require(latestProposalState != ProposalState.Pending, "One proposal per proposer - pending proposal already found");
            require(latestProposalState != ProposalState.Active, "One proposal per proposer - active proposal already found");
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.quorumVotes = max(1, bps2Uint(quorumVotesBPS, token.totalSupply()));
        proposal.eta = 0;
        proposal.targets = targets;
        proposal.values = values;
        proposal.signatures = signatures;
        proposal.calldatas = calldatas;
        proposal.startBlock = startBlock;
        proposal.endBlock = endBlock;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstainVotes = 0;
        proposal.canceled = false;
        proposal.executed = false;
        proposal.vetoed = false;
        latestProposalIds[proposal.proposer] = proposal.id;

        emit ProposalCreated(
            proposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            proposal.quorumVotes,
            description
        );

        return proposal.id;
    }

    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            'proposal queueable only if succeeded'
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i],
            proposal.values[i],
            proposal.signatures[i],
            proposal.calldatas[i],
            eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
            'identical proposal already queued at eta'
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function execute(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Queued,
            'proposal can only be executed if queued'
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        require(state(proposalId) != ProposalState.Executed, 'proposal already executed');
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            token.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold,
            'only proposer can cancel unless their votes drop below proposal threshold'
        );
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
        emit ProposalCanceled(proposalId);
    }

    function veto(uint256 proposalId) external {
        require(vetoer != address(0), 'veto power burned');
        require(msg.sender == vetoer, 'only vetoer can veto');
        require(state(proposalId) != ProposalState.Executed, 'cannot veto executed proposal');
        Proposal storage proposal = proposals[proposalId];

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

    function getActions(uint256 proposalId) external view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

	function state(uint256 proposalId) public view override returns (ProposalState) {
		require(proposalCount >= proposalId, "Invalid proposal ID");
		Proposal storage proposal = proposals[proposalId];
		if (proposal.vetoed) {
			return ProposalState.Vetoed;
		} else if (proposal.canceled) {
			return ProposalState.Canceled;
		} else if (block.number <= proposal.startBlock) {
			return ProposalState.Pending;
		} else if (block.number <= proposal.endBlock) {
			return ProposalState.Active;
		} else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < proposal.quorumVotes) {
			return ProposalState.Defeated;
		} else if (proposal.eta == 0) {
			return ProposalState.Succeeded;
		} else if (proposal.executed) {
			return ProposalState.Executed;
		} else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
			return ProposalState.Expired;
		} else {
			return ProposalState.Queued;
		}
	}

	function castVote(uint256 proposalId, uint8 support) external override {
		emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), "");
	}

	function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external override {
		emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), reason);
	}

	function castVoteBySig(
		uint256 proposalId,
		uint8 support,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external override {
		address signatory = ECDSA.recover(
			_hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support))),
			v,
			r,
			s
		);
		emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), "");
	}

	function castVoteInternal(
		address voter,
		uint256 proposalId,
		uint8 support
	) internal returns (uint32) {
		require(state(proposalId) == ProposalState.Active, 'voting is closed');
		require(support <= 2, 'invalid vote type');
		Proposal storage proposal = proposals[proposalId];
		Receipt storage receipt = proposal.receipts[voter];
		require(!receipt.hasVoted, "voter already voted!");

		uint32 votes = token.getPriorVotes(voter, proposal.startBlock - votingDelay);
		if (support == 0) {
			proposal.againstVotes = proposal.againstVotes + votes;
		} else if (support == 1) {
			proposal.forVotes = proposal.forVotes + votes;
		} else {
			proposal.abstainVotes = proposal.abstainVotes + votes;
		}

		receipt.hasVoted = true;
		receipt.support = support;
		receipt.votes = votes;
		return votes;
	}

	function setVotingDelay(uint256 newVotingDelay) external override onlyAdmin {
		require(
			newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY,
			'invalid voting delay'
		);
		uint256 oldVotingDelay = votingDelay;
		votingDelay = newVotingDelay;

		emit VotingDelaySet(oldVotingDelay, votingDelay);
	}

	function setQuorumVotesBPS(uint256 newQuorumVotesBPS) external override onlyAdmin {
		require(
			newQuorumVotesBPS >= MIN_QUORUM_VOTES_BPS && newQuorumVotesBPS <= MAX_QUORUM_VOTES_BPS,
			'invalid quorum votes threshold set'
		);
		uint256 oldQuorumVotesBPS = quorumVotesBPS;
		quorumVotesBPS = newQuorumVotesBPS;
		emit QuorumVotesBPSSet(oldQuorumVotesBPS, quorumVotesBPS);
	}


	function setVotingPeriod(uint256 newVotingPeriod) external override onlyAdmin {
		require(
			newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD,
			"invalid voting period"
		);
		uint256 oldVotingPeriod = votingPeriod;
		votingPeriod = newVotingPeriod;

		emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
	}

	function setProposalThreshold(uint256 newProposalThreshold) external override onlyAdmin {
		require(newProposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
			newProposalThreshold <= maxProposalThreshold(),
			'invalid proposal threshold'
		);
		uint256 oldProposalThreshold = proposalThreshold;
		proposalThreshold = newProposalThreshold;

		emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
	}

	function setPendingAdmin(address _pendingAdmin) external override onlyAdmin {
		address oldPendingAdmin = pendingAdmin;
		pendingAdmin = _pendingAdmin;

		emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
	}

    function setVetoer(address _vetoer) public {
        require(msg.sender == vetoer, 'vetoer only');
        emit NewVetoer(vetoer, _vetoer);
        vetoer = _vetoer;
    }

    function revokeVetoPower() external {
        require(msg.sender == vetoer, 'vetoer only');
        setVetoer(address(0));
    }

	function acceptAdmin() external override onlyPendingAdmin {

		address oldAdmin = admin;
		address oldPendingAdmin = pendingAdmin;

		admin = pendingAdmin;
		pendingAdmin = address(0);

		emit NewAdmin(oldAdmin, admin);
		emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
	}

	function maxProposalThreshold() public view returns (uint256) {
		return max(MIN_PROPOSAL_THRESHOLD, bps2Uint(MAX_PROPOSAL_THRESHOLD_BPS, token.totalSupply()));
	}

	function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
		return interfaceId == type(IRaritySocietyDAO).interfaceId || super.supportsInterface(interfaceId);
	}

	function bps2Uint(uint256 bps, uint number) internal pure returns (uint256) {
		return (number * bps) / 10000;
	}

	function max(uint256 a, uint256 b) internal pure returns (uint256) {
		return a >= b ? a : b;
	}

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                name,
                version,
                block.chainid,
                address(this)
            )
        );
    }

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

}
