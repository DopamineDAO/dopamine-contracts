// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Dopamine Auction House Proxy Contract
/// @notice This contract serves as the placeholder UUPS proxy for upgrading and
///  initializing the Dopamine Auction House implementation contract.
contract DopamineAuctionHouseProxy is ERC1967Proxy {

    /// @notice Initializes the Dopamine DAO Auction House.
    /// @param logic The address of the Dopamine Auction House implementation.
    /// @param data ABI-encoded Dopamine Auction House initialization data.
    constructor(address logic, bytes memory data) ERC1967Proxy(logic, data) {}
}
