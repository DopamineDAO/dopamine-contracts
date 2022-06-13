// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine DAO Governance Token
/// @notice Although Dopamine DAO is intended to be integrated with the Dopamine
///  ERC-721 tab (see DopamineTab.sol), any governance contract supporting the
///  following interface definitions can be used. Later on, Dopamine will
///  upgrade the DAO contract to support another second-tier governance token.
///  When this happens, the token must support the IDopamineDAOToken interface.
/// @dev The total voting weight can be no larger than `type(uint32).max`.
interface IDopamineDAOToken {

    /// @notice Get number of votes for `voter` at block number `blockNumber`.
    /// @param voter Address of the voter being queried.
    /// @param blockNumber Block number to tally votes from.
    /// @return The total tallied votes of `voter` at `blockNumber`.
    function priorVotes(address voter, uint256 blockNumber)
        external view returns (uint32);

    /// @notice Retrieves the token supply for the contract.
    /// @return The total circulating supply of the gov token as a uint256.
    function totalSupply() external view returns (uint256);

}
