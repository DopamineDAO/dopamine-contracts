// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./IDopamineHonoraryPassEvents.sol";

/// @title Dopamine ERC-721 honorary membership pass interface
interface IDopamineHonoraryPass is IDopamineHonoraryPassEvents {

    /// @notice Mints an honorary Dopamine pass to address `to`.
    /// @dev This function is only callable by the admin address.
    function mint(address to) external;

    /// @notice Gets the admin address, which controls minting & royalties.
    function admin() external view returns (address);

    /// @notice Retrieves a URI describing the overall contract-level metadata.
    /// @return A string URI pointing to the pass contract metadata.
    function contractURI() external view returns (string memory);

    /// @notice Sets the admin address to `newAdmin`.
    /// @param newAdmin The address of the new admin.
    /// @dev This function is only callable by the admin address.
    function setAdmin(address newAdmin) external;

    /// @notice Sets the base URI to `newBaseURI`.
    /// @param newBaseURI The new base metadata URI to set for the collection.
    /// @dev This function is only callable by the admin address.
    function setBaseURI(string calldata newBaseURI) external;

    /// @notice Sets the permanent storage URI to `newStorageURI`.
    /// @param newStorageURI The new permanent URI to set for the collection.
    /// @dev This function is only callable by the admin address.
    function setStorageURI(string calldata newStorageURI) external;

    /// @notice Sets the royalties for the NFT collection.
    /// @param receiver Address to which royalties will be received.
    /// @param royalties The amount of royalties to receive, in bips.
    /// @dev This function is only callable by the admin address.
    function setRoyalties(address receiver, uint96 royalties) external;

}
