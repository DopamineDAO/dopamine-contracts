// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////
 
/// @title Dopamine DAO ERC-721 Membership Pass Events Interface
interface IDopaminePassEvents {

    /// @notice Emits when the Dopamine pass base URI is set to `baseUri`.
    /// @param baseUri The base URI of the Dopamine pass contract, as a string.
	event BaseURISet(string baseUri);

    /// @notice Emits when a new drop is created by the Dopamine pass admin.
    /// @param dropId         The id of the newly created drop.
    /// @param startIndex     The id of the first passincluded in the drop.
    /// @param dropSize       The number of passes to distribute in the drop.
    /// @param whitelistSize  The number of whitelisted passes in the drop.
    /// @param whitelist      A merkle root of the included address-pass pairs.
    /// @param provenanceHash SHA-256 hash of combined image hashes in the drop.
    event DropCreated(
        uint256 indexed dropId,
        uint256 startIndex,
        uint256 dropSize,
        uint256 whitelistSize,
        bytes32 whitelist,
        bytes32 provenanceHash
    );

    /// @notice Emits when a new drop delay `dropDelay` is set.
    /// @param dropDelay The new drop delay to set, in seconds.
    event DropDelaySet(uint256 dropDelay);

    /// @notice Emits when a new drop size `dropSize` is set.
    /// @param dropSize The new drop size, in number of passes to distribute.
    event DropSizeSet(uint256 dropSize);

    /// @notice Emits when the drop of id `id` has its URI set to `dropUr1`.
    /// @param id  The id of the drop whose URI was set.
    /// @param dropUri The metadata URI of the drop, as a string.
	event DropURISet(uint256 indexed id, string dropUri);

    /// @notice Emits when a new whitelist size `whitelistSize` is set.
    /// @param whitelistSize The number of passes to whitelist for drops.
    event WhitelistSizeSet(uint256 whitelistSize);

    /// @notice Emits when minter is changed from `oldMinter` to `newMinter`.
    /// @param oldMinter The address of the previous minter.
    /// @param newMinter The address of the new minter.
    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    /// @notice Emits when admin is changed from `oldAdmin` to `newAdmin`.
    /// @param oldAdmin The address of the previous admin.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

}
