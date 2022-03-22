// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import { ITimelock } from "../interfaces/ITimelock.sol";
import { IDopamineDAOToken } from "../interfaces/IDopamineDAOToken.sol";
import { IDopamineDAO } from "../interfaces/IDopamineDAO.sol";

/// @title Dopamine DAO Storage Contract
/// @dev Upgrades involving new storage variables should utilize a new contract
///  inheriting the prior storage contract. This would look like the following:
///  `contract DopamineDAOStorageV1 is DopamineDAOStorage { ... }`   (upgrade 1)
///  `contract DopamineDAOStorageV2 is DopamineDAOStorageV1 { ... }` (upgrade 2)
contract DopamineDAOStorage {

    /// @notice The id of the ongoing  proposal.
    uint32 public proposalId;

    /// @notice The address administering proposal lifecycles and DAO settings.
    address public admin;

    /// @notice Address of temporary admin that will become admin once accepted.
    address public pendingAdmin;

    /// @notice Address with ability to veto proposals (intended to be revoked).
    address public vetoer;

    /// @notice The time in blocks a proposal is eligible to be voted on.
    uint256 public votingPeriod;

    /// @notice The time in blocks to wait until a proposal opens up for voting.
    uint256 public votingDelay;

    /// @notice The number of voting units needed for a proposal to be created.
    uint256 public proposalThreshold;

    /// @notice The quorum threshold, in bips, a proposal requires to pass.
    uint256 public quorumThresholdBPS;

    /// @notice The timelock, responsible for coordinating proposal execution.
    ITimelock public timelock;

    /// @notice The Dopamine DAO governance token (the ERC-721 Dopamine pass).
    IDopamineDAOToken public token;

    /// @notice The ongoing proposal.
    IDopamineDAO.Proposal public proposal;

    /// @dev A map of voters to their last voted upon proposal ids.
    mapping(address => uint256) internal _lastVotedProposal;

}
