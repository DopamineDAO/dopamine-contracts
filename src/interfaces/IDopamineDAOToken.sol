// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////
  
/// @title Dopamine DAO Governance Token
/// @notice Although Dopamine DAO is intended to be integrated with the Dopamine
///  ERC-721 pass (see DopamintPass.sol), any governance contract supporting the
///  following interface definitions can be used. In the future, it is possible 
///  that Dopamine DAO will upgrade to support another second-tier governance 
///  If this happens, the token must support the IDopamineDAOToken interface.
/// @dev The total voting weight can be no larger than `type(uint32).max`.
interface IDopamineDAOToken {

    /// @notice Get number of votes for `voter` at block number `blockNumber`.
    /// @param voter       Address of the voter being queried.
    /// @param blockNumber Block number to tally votes from.
    /// @return The total tallied votes of `voter` at `blockNumber`.
    function priorVotes(address voter, uint blockNumber) 
        external view returns (uint32);

    /// @notice Retrieves the token supply for the contract.
    /// @return The total circulating supply of the gov token as a uint256.
    function totalSupply() external view returns (uint256);

}
