// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./IDopaminePassEvents.sol";

/// @title Dopamine DAO ERC-721 membership pass interface
interface IDopaminePass is IDopaminePassEvents {

    /// @notice Mints a dopamine pass to the minter address.
    /// @dev This function is only callable by the minter address.
    /// @return Id of the minted pass, which is always equal to `_id`.
    function mint() external returns (uint256);

    /// @notice Mints a whitelisted pass of id `id` to the sender address if
    ///  merkle proof `proof` proves they were whitelisted with that pass id.
    /// @dev Reverts if invalid proof is provided or claimer isn't whitelisted.
    ///  The whitelist is formed using encoded tuple leaves (address, id). The
    ///  Merkle Tree JS library used: https://github.com/miguelmota/merkletreejs
    /// @param proof The Merkle proof of the claim as a bytes32 array.
    /// @param id    The id of the Dopamine pass being claimed.
    function claim(bytes32[] calldata proof, uint256 id) external;

    /// @notice Creates a new Dopamine pass drop.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  an ongoing drop exists, call is too early, or maximum capacity reached.
    /// @param whitelist A merkle root whose tree is comprised of whitelisted 
    ///  addresses and their assigned pass ids. This assignment is permanent.
    /// @param provenanceHash An immutable provenance hash equal to the SHA-256
    ///  hash of the concatenation of all SHA-256 image hashes of the drop.
    function createDrop(bytes32 whitelist, bytes32 provenanceHash) external;

    /// @notice Gets the admin address, which controls drop settings & creation.
    function admin() external view returns (address);

    /// @notice Gets the minter address, which controls Dopamine pass emissions.
    function minter() external view returns (address);

    /// @notice Gets the time needed to wait in seconds between drop creations.
    function dropDelay() external view returns (uint256);

    /// @notice Gets the last token id of the current drop (exclusive boundary).
    function dropEndIndex() external view returns (uint256);

    /// @notice Gets the time at which a new drop can start (if last completed).
    function dropEndTime() external view returns (uint256);

    /// @notice Gets the current number of passes to be distributed each drop.
    /// @dev This includes the number of passes whitelisted for the drop.
    function dropSize() external view returns (uint256);

    /// @notice Gets the number of passes allocated for whitelisting each drop.
    function whitelistSize() external view returns (uint256);

    /// @notice Retrieves the provenance hash for a drop with id `dropId`.
    /// @param dropId The id of the drop being queried.
    /// @return SHA-256 hash of all sequenced SHA-256 image hashes of the drop.
    function dropProvenanceHash(uint256 dropId) external view returns (bytes32);

    /// @notice Retrieves the metadata URI for a drop with id `dropId`.
    /// @param dropId The id of the drop being queried.
    /// @return URI of the drop's metadata as a string.
    function dropURI(uint256 dropId) external view returns (string memory);

    /// @notice Retrieves the whitelist for a drop with id `dropId`.
    /// @dev See `claim()` for details regarding whitelist generation.
    /// @param dropId The id of the drop being queried.
    /// @return The drop's whitelist, as a bytes32 merkle tree root.
    function dropWhitelist(uint256 dropId) external view returns (bytes32);

    /// @notice Retrieves the drop id of the pass with id `id`.
    /// @return The drop id of the queried pass.
    function dropId(uint256 id) external view returns (uint256);

    /// @notice Retrieves a URI describing the overall contract-level metadata.
    /// @return A string URI pointing to the pass contract metadata.
    function contractURI() external view returns (string memory);

    /// @notice Sets the minter address to `newMinter`.
    /// @param newMinter The address of the new minter.
    /// @dev This function is only callable by the admin address.
    function setMinter(address newMinter) external;

    /// @notice Sets the admin address to `newAdmin`.
    /// @param newAdmin The address of the new admin.
    /// @dev This function is only callable by the admin address.
    function setAdmin(address newAdmin) external;

    /// @notice Sets the base URI to `newBaseURI`.
    /// @param newBaseURI The new base metadata URI to set for the collection.
    /// @dev This function is only callable by the admin address.
	function setBaseURI(string calldata newBaseURI) external;

    /// @notice Sets the final metadata URI for drop `dropId` to `dropURI`.
    /// @dev This function is only callable by the admin address, and reverts
    ///  if the specified drop `dropId` does not exist.
    /// @param id      The id of the drop whose final metadata URI is being set.
	/// @param dropURI The finalized IPFS / Arweave metadata URI.
    function setDropURI(uint256 id, string calldata dropURI) external;

    /// @notice Sets the drop delay `dropDelay` to `newDropDelay`.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  the drop delay is too small or too large.
    /// @param newDropDelay The new drop delay to set, in seconds.
    function setDropDelay(uint256 newDropDelay) external;

    /// @notice Sets the drop size to `newDropSize`.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  the specified drop size is too small or too large.
    /// @param newDropSize The new drop size to set, in terms of pass units.
    function setDropSize(uint256 newDropSize) external;

    /// @notice Sets the drop whitelist size to `newWhitelistSize`.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  the whitelist size is too large or greater than the existing drop size.
    /// @param newWhitelistSize The new drop whitelist size to set.
    function setWhitelistSize(uint256 newWhitelistSize) external;

}
