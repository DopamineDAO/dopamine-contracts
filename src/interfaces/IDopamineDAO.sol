// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./IDopamineDAOEvents.sol";

interface IDopamineDAO is IDopamineDAOEvents {

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint32);

    function queue() external;

    function execute() external;

    function cancel() external;

    function veto() external;

    function castVote(uint8 support) external;

    function castVoteBySig(
		address voter,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function getActions() external view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    );

    function state() external view returns (ProposalState);

    function setVotingDelay(uint32 newVotingDelay) external;

    function setVotingPeriod(uint32 newVotingPeriod) external;

    function setProposalThreshold(uint32 newProposalThreshol) external;

    function setQuorumThresholdBPS(uint32 newQuorumThresholdBPS) external;

    function setVetoer(address newVetoer) external;

    function setPendingAdmin(address newPendingAdmin) external;

    function acceptAdmin() external;

	function MAX_PROPOSAL_THRESHOLD() external view returns (uint32);

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
        uint256 eta;

        address proposer;
        uint32 id;
        uint32 quorumThreshold;
        uint32 proposalThreshold;

        uint32 startBlock;
        uint32 endBlock;
        uint32 forVotes;
        uint32 againstVotes;
        uint32 abstainVotes;
        bool vetoed;
        bool canceled;
        bool executed;

        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    struct Receipt {
        uint32 id;
        uint8 support;
        uint32 votes;
    }

}
