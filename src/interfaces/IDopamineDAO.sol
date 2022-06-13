// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import {IDopamineDAOEvents} from "./IDopamineDAOEvents.sol";

/// @title Dopamine DAO Implementation Interface
interface IDopamineDAO is IDopamineDAOEvents {

    /// @notice ProposalState represents the current proposal's lifecycle state.
    enum ProposalState {

        /// @notice On creation, proposals are Pending till voting delay passes.
        Pending,

        /// @notice Active proposals can be voted on, until voting period ends.
        Active,

        /// @notice Once a proposer cancels their proposal it becomes Canceled.
        Canceled,

        /// @notice Defeated means votes didn't hit quorum / are mainly Against.
        Defeated,

        /// @notice Succeeded proposals have majority For votes at voting end.
        Succeeded,

        /// @notice Queued represents a Succeeded proposal that was queued.
        Queued,

        /// @notice Expired means failure to execute by ETA + grace period time.
        Expired,

        /// @notice A Queued proposal which is successfully executed at its ETA.
        Executed,

        /// @notice Once a vetoer vetoes a proposal, it becomes vetoed.
        Vetoed
    }

    /// @notice Proposal is an encapsulation of the ongoing proposal.
    struct Proposal {

        /// @notice Block timestamp at which point proposal ready for execution.
        uint256 eta;

        /// @notice The address that created the proposal.
        address proposer;

        /// @notice The number of votes required for proposal success.
        uint32 quorumThreshold;

        /// @notice The block at which point the proposal is considered active.
        uint32 startBlock;

        /// @notice The last block at which votes may be cast for the proposal.
        uint32 endBlock;

        /// @notice The tally of the number of Against votes (vote type = 0).
        uint32 againstVotes;

        /// @notice The tally of the number of For votes (vote type = 1).
        uint32 forVotes;

        /// @notice The tally of the number of Abstain votes (vote type = 2).
        uint32 abstainVotes;

        /// @notice Boolean indicating whether the proposal was vetoed.
        bool vetoed;

        /// @notice Boolean indicating whether the proposal was canceled.
        bool canceled;

        /// @notice Boolean indicating whether the proposal was executed.
        bool executed;

        /// @notice List of target addresses for the proposal execution calls.
        address[] targets;

        /// @notice Amounts (in wei) to send for proposal execution calls.
        uint256[] values;

        /// @notice The function signatures of the proposal execution calls.
        string[] signatures;

        /// @notice Calldata passed with the proposal execution calls.
        bytes[] calldatas;
    }

    /// @notice Creates a new proposal.
    /// @dev This reverts if the existing proposal has yet to be settled.
    /// @param targets Target addresses for the calls being executed.
    /// @param values Amounts (in wei) to send for the execution calls.
    /// @param signatures The function signatures of the execution calls.
    /// @param calldatas Calldatas to be passed with the execution calls.
    /// @param description A string description of the overall proposal.
    /// @return The proposal identifier associated with the created proposal.
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    /// @notice Queues the current proposal if successfully passed.
    /// @dev Reverts if wrong proposal id is specified or if it's yet to pass.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    function queue(uint256 id) external;

    /// @notice Executes the current proposal if successfully queued.
    /// @dev Reverts if wrong id given, proposal yet to pass, or timelock fails.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    function execute(uint256 id) external;

    /// @notice Cancel the current proposal if not yet settled.
    /// @dev Reverts if wrong id given, proposal executed, or proposer invalid.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    function cancel(uint256 id) external;

    /// @notice Veto the proposal if not yet settled, only if sender is vetoer.
    /// @dev Reverts if proposal executed, vetoer invalid, or veto power voided.
    function veto() external;

    /// @notice Cast vote of type `support` for the current proposal.
    /// @dev Reverts if wrong id or vote type  given, proposal inactive, or vote
    ///  already cast. Voting weight is sourced from proposal creation block.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    /// @param support The vote type: 0 = against, 1 = for, 2 = abstain
    function castVote(uint256 id, uint8 support) external;

    /// @notice Same as `castVote`, with an added `reason` message provided.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    /// @param support The vote type: 0 = against, 1 = for, 2 = abstain
    /// @param reason A string message explaining the choice of vote selection.
    function castVoteWithReason(
        uint256 id,
        uint8 support,
        string calldata reason
    ) external;

    /// @notice Cast vote of type `support` for current proposal via signature.
    /// @dev See `castVote` details. In addition, reverts if signature invalid.
    /// @param id The current proposal id (for Governor Bravo compatibility).
    /// @param support The vote type: 0 = against, 1 = for, 2 = abstain
    /// @param v Transaction signature recovery identifier.
    /// @param r Transaction signature output component #1.
    /// @param s Transaction signature output component #2.
    function castVoteBySig(
        uint256 id,
        address voter,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Retrieves the current quorum threshold, in number of NFTs.
    /// @return The number of governance tokens needed for a proposal to pass.
    function quorumThreshold() external view returns (uint256);

    /// @notice Retrieves the maximum allowed proposal threshold in NFT units.
    /// @dev This function ensures proposal threshold is non-zero in the case
    ///  when the proposal bips value multiplied by NFT supply is equal to 0.
    /// @return The maximum allowed proposal threshold, in number of NFTs.
    function maxProposalThreshold() external view returns (uint256);

    /// @notice Retrieves the current proposal's state.
    /// @return The current proposal's state, as a `ProposalState` struct.
    function state() external view returns (ProposalState);

    /// @notice Retrieve the actions of the current proposal.
    /// @return targets     Target addresses for the calls being executed.
    /// @return values      Amounts (in wei) to be sent for the execution calls.
    /// @return signatures  The function signatures of theexecution calls.
    /// @return calldatas   Calldata to be passed with each execution call.
    function actions()
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );

    /// @notice Sets the proposal voting delay to `newVotingDelay`.
    /// @dev This function is only callable by the admin, and throws if the
    ///  voting delay is too low or too high.
    /// @param newVotingDelay The new voting delay to set, in blocks.
    function setVotingDelay(uint256 newVotingDelay) external;

    /// @notice Sets the proposal voting period to `newVotingPeriod`.
    /// @dev This function is only callable by the admin, and throws if the
    ///  voting period is too low or too high.
    /// @param newVotingPeriod The new voting period to set, in blocks.
    function setVotingPeriod(uint256 newVotingPeriod) external;

    /// @notice Sets the proposal threshold to `newProposalThreshold`.
    /// @dev This function is only callable by the admin, and throws if the
    ///  proposal threshold is too low or above `maxProposalThreshold()`.
    /// @param newProposalThreshold The new NFT proposal threshold to set.
    function setProposalThreshold(uint256 newProposalThreshold) external;

    /// @notice Sets the quorum threshold (in bips) to `newQuorumThresholdBPS`.
    /// @dev This function is only callable by the admin, and throws if the
    ///  quorum threshold bips value is too low or too high.
    /// @param newQuorumThresholdBPS The new quorum voting threshold, in bips.
    function setQuorumThresholdBPS(uint256 newQuorumThresholdBPS) external;

    /// @notice Sets the vetoer address to `newVetoer`.
    /// @dev Veto power should be revoked after sufficient NFT distribution, at
    ///  which point this function will throw (e.g. when vetoer = `address(0)`).
    /// @param newVetoer The new vetoer address.
    function setVetoer(address newVetoer) external;

    /// @notice Sets the pending admin address to  `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
    function setPendingAdmin(address newPendingAdmin) external;

    /// @notice Assigns the `pendingAdmin` address to the `admin` address.
    /// @dev This function is only callable by the pending admin.
    function acceptAdmin() external;

}
