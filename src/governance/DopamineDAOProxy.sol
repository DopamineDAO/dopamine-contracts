// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Dopamine DAO Proxy Contract
/// @notice This contract serves as the UUPS proxy for upgrading and
///  initializing the Dopamine DAO implementation contract.
contract DopamineDAOProxy is ERC1967Proxy {

    /// @notice Initializes the Dopamine DAO governance platform.
    /// @param logic The address of the Dopamine DAO implementation contract.
    /// @param data ABI-encoded Dopamine DAO initialization data.
    constructor(address logic, bytes memory data) ERC1967Proxy(logic, data) {}

}
