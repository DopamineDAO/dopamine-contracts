pragma solidity ^0.8.9;

interface IRaritySocietyDAO {

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        uint256 quorumVotes,
        string description
    );

    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

    event ProposalCanceled(uint256 id);

    event ProposalQueued(uint id, uint eta);

    event ProposalExecuted(uint id);

    event ProposalVetoed(uint256 id);

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    event QuorumVotesBPSSet(uint256 oldQuorumVotesBPS, uint256 newQuorumVotesBPS);

    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    event NewAdmin(address oldAdmin, address newAdmin);

    event NewVetoer(address oldVetoer, address newVetoer);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external;

    function cancel(uint256 proposalId) external;

    function veto(uint256 proposalId) external;

    function castVote(uint256 proposalId, uint8 support) external;

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external;

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function getActions(uint256 proposalId) external view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    );

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);


    function state(uint256 proposalId) external view returns (ProposalState);

    function setVotingDelay(uint256 newVotingDelay) external;

    function setVotingPeriod(uint256 newVotingPeriod) external;

    function setProposalThreshold(uint256 newProposalThreshol) external;

    function setQuorumVotesBPS(uint256 newQuorumVotesBPS) external;

    function setVetoer(address newVetoer) external;

    function revokeVetoPower() external;

    function setPendingAdmin(address newPendingAdmin) external;

    function acceptAdmin() external;

	function maxProposalThreshold() external view returns (uint256);

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed
    }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 quorumVotes;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool vetoed;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint32 votes;
    }



}
