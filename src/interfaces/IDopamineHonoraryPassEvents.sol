// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine ERC-721 Honorary Membership Pass Events Interface
interface IDopamineHonoraryPassEvents {

    /// @notice Emits when the Dopamine pass base URI is set to `baseUri`.
    /// @param baseURI The base URI of the pass contract, as a string.
    event BaseURISet(string baseURI);

    /// @notice Emits when the Dopamine pass storage URI is set to `StorageUri`.
    /// @param storageURI The storage URI of the pass contract, as a string.
    event StorageURISet(string storageURI);

    /// @notice Emits when admin is changed from `oldAdmin` to `newAdmin`.
    /// @param oldAdmin The address of the previous admin.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

}
