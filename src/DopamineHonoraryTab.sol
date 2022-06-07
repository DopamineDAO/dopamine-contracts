// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./errors.sol";
import { IDopamineHonoraryTab } from "./interfaces/IDopamineHonoraryTab.sol";
import { IProxyRegistry } from "./interfaces/IProxyRegistry.sol";
import { ERC721h } from "./erc721/ERC721h.sol";

/// @title Dopamine honorary ERC-721 membership tab
/// @notice Dopamine honorary tabs are vanity tabs for friends of Dopamine.
contract DopamineHonoraryTab is ERC721h, IDopamineHonoraryTab {

    /// @notice The address owneristering minting and metadata settings.
    address public owner;

    /// @notice The OS registry address - whitelisted for gasless OS approvals.
    IProxyRegistry public proxyRegistry;

    /// @notice The URI each tab initially points to for metadata resolution.
    /// @dev Before drop completion, `tokenURI()` resolves to "{baseURI}/{id}".
    string public baseURI = "https://dev-api.dopamine.xyz/honoraries/";

    /// @notice The permanent URI tabs will point to on collection finality.
    /// @dev Post drop completion, `tokenURI()` resolves to "{storageURI}/{id}".
    string public storageURI;

    /// @notice Restricts a function call to address `owner`.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OwnerOnly();
        }
        _;
    }

    /// @notice Initializes the Dopamine honorary membership tab contract.
    /// @param proxyRegistry_ The OS proxy registry address.
    /// @param reserve_ Address to which royalties direct to.
    /// @param royalties_ Royalties send to `resereve_` on sales, in bips.
    /// @dev `owner` is intended to eventually switch to the Dopamine DAO proxy.
    constructor(
        IProxyRegistry proxyRegistry_,
        address reserve_,
        uint96 royalties_
    ) ERC721h("Dopamine Honorary Tabs", "HDOPE") {
        owner = msg.sender;
        proxyRegistry = proxyRegistry_;
        _setRoyalties(reserve_, royalties_);
    }

    /// @inheritdoc IDopamineHonoraryTab
    function mint(address to) external onlyOwner {
        return _mint(owner, to);
    }

    /// @inheritdoc IDopamineHonoraryTab
    function contractURI() external view returns (string memory)  {
        return string(abi.encodePacked(baseURI, "collection"));
    }

    /// @inheritdoc IDopamineHonoraryTab
    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnerChanged(owner, newOwner);
    }

    /// @inheritdoc IDopamineHonoraryTab
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    /// @inheritdoc IDopamineHonoraryTab
    function setStorageURI(string calldata newStorageURI) external onlyOwner {
        storageURI = newStorageURI;
        emit StorageURISet(newStorageURI);
    }

    /// @inheritdoc IDopamineHonoraryTab
    function setRoyalties(
        address receiver,
        uint96 royalties
    ) external onlyOwner {
        _setRoyalties(receiver, royalties);
    }

    /// @inheritdoc ERC721h
    /// @dev Before all honoraries are minted, the token URI for tab of id `id`
    ///  defaults to {baseURI}/{id}. Once all honoraries are minted, this will
    ///  be replaced with a decentralized storage URI (Arweave / IPFS) given by
    ///  {storageURI}/{id}. If `id` does not exist, this function reverts.
    /// @param id The id of the NFT being queried.
    function tokenURI(uint256 id)
        public
        view
        virtual
        override(ERC721h)
        returns (string memory)
    {
        if (ownerOf[id] == address(0)) {
            revert TokenNonExistent();
        }

        string memory uri = storageURI;
        if (bytes(uri).length == 0) {
            uri = baseURI;
        }
        return string(abi.encodePacked(uri, _toString(id)));
    }

    /// @dev Ensures OS proxy is whitelisted for operating on behalf of owners.
    /// @inheritdoc ERC721h
    function isApprovedForAll(address owner, address operator)
    public
    view
        override
        returns (bool)
    {
        return
            proxyRegistry.proxies(owner) == operator ||
            _operatorApprovals[owner][operator];
    }

    /// @dev Converts a uint256 into a string.
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
