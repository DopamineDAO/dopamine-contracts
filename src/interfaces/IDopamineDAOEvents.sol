pragma solidity ^0.8.9;

interface IDopamineDAOEvents {

    event ProposalCreated(
        uint32 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint32 startBlock,
        uint32 endBlock,
        uint32 quorumThreshold,
        string description
    );

    event VoteCast(address indexed voter, uint32 proposalId, uint8 support, uint32 votes);

    event ProposalCanceled(uint32 id);

    event ProposalQueued(uint32 id, uint256 eta);

    event ProposalExecuted(uint32 id);

    event ProposalVetoed(uint32 id);

    event VotingDelaySet(uint32 votingDelay);

    event VotingPeriodSet(uint32 votingPeriod);

    event ProposalThresholdSet(uint32 proposalThreshold);

    event QuorumThresholdBPSSet(uint256 quorumThresholdBPS);

    event NewPendingAdmin(address pendingAdmin);

    event NewAdmin(address oldAdmin, address newAdmin);

    event NewVetoer(address vetoer);

}
