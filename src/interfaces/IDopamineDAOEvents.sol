// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine DAO Events Interface
interface IDopamineDAOEvents {

    /// @notice Emits when a new proposal is created.
    /// @param id The id of the newly created proposal.
    /// @param proposer The address which created the new proposal.
    /// @param targets Target addresses for the calls to be executed.
    /// @param values Amounts (in wei) to send for the execution calls.
    /// @param signatures The function signatures of the execution calls.
    /// @param calldatas Calldatas to be passed with the execution calls.
    /// @param startBlock The block at which voting opens for the proposal.
    /// @param endBlock The block at which voting ends for the proposal.
    /// @param description A string description of the overall proposal.
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint32 startBlock,
        uint32 endBlock,
        string description
    );

    /// @notice Emits when a proposal is queued for execution.
    /// @param id The id of the queued proposal.
    /// @param eta Timestamp in seconds at which the proposal may be executed.
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice Emits when a proposal is canceled by its proposer.
    /// @param id The id of the canceled proposal.
    event ProposalCanceled(uint256 id);

    /// @notice Emits when a proposal is successfully executed.
    /// @param id The id of the executed proposal.
    event ProposalExecuted(uint256 id);

    /// @notice Emits when a proposal is vetoed by the vetoer.
    /// @param id The id of the vetoed proposal.
    event ProposalVetoed(uint256 id);

    /// @notice Emits when voter `voter` casts `votes` votes of type `support`.
    /// @param voter The address of the voter whose vote was cast.
    /// @param id The id of the voted upon proposal.
    /// @param support The vote type: 0 = against, 1 = for, 2 = abstain
    /// @param votes The total number of NFTs assigned to the vote's weight.
    /// @param reason A string message explaining the choice of vote selection.
    event VoteCast(
        address indexed voter,
        uint256 id,
        uint8 support,
        uint256 votes,
        string reason
    );

    /// @notice Emits when a new voting delay `votingDelay` is set.
    /// @param votingDelay The new voting delay set, in blocks.
    event VotingDelaySet(uint256 votingDelay);

    /// @notice Emits when a new voting period `votingPeriod` is set.
    /// @param votingPeriod The new voting period set, in blocks.
    event VotingPeriodSet(uint256 votingPeriod);

    /// @notice Emits when a new proposal threshold `proposalThreshold` is set.
    /// @param proposalThreshold The proposal threshold set, in NFT units.
    event ProposalThresholdSet(uint256 proposalThreshold);

    /// @notice Emits when a new quorum threshold `quorumThresholdBPS` is set.
    /// @param quorumThresholdBPS The new quorum threshold set, in bips.
    event QuorumThresholdBPSSet(uint256 quorumThresholdBPS);

    /// @notice Emits when a new pending admin `pendingAdmin` is set.
    /// @param pendingAdmin The new address of the pending admin that was set.
    event PendingAdminSet(address pendingAdmin);

    /// @notice Emits when vetoer is changed from `oldVetoer` to `newVetoe+`.
    /// @param oldVetoer The address of the previous vetoer.
    /// @param newVetoer The address of the new vetoer.
    event VetoerChanged(address oldVetoer, address newVetoer);

}
