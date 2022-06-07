// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// Transfer & minting methods derive from ERC721.sol of solmate:
/// https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol
/// Credit goes to Transmissions11 (Solmate author) for these gas optimizations.

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC2981} from "../interfaces/IERC2981.sol";

import "../errors.sol";

/// @title Dopamine ERC-721 contract built for Dopamine honorary tabs.
/// @notice This is a minimal ERC-721 implementation that supports the metadata
///  extension, total supply tracking, and ERC-2981 royalties support.
/// @dev This ERC-721 implementation is optimized for mints and transfers of
///  individual tokens (as opposed to bulk). It also includes EIP-712 methods &
///  data structures to allow for signing processes to be built on top of it.
contract ERC721h is IERC721, IERC721Metadata, IERC2981 {

    /// @notice The name of the token collection.
    string public name;

    /// @notice The abbreviated name of the token collection.
    string public symbol;

    /// @notice The total number of tokens in circulation.
    uint256 public totalSupply;

    /// @notice Gets the number of NFTs owned by an address.
    /// @dev This implementation does not throw for zero-address queries.
    mapping(address => uint256) public balanceOf;

    /// @notice Gets the assigned owner of an address.
    /// @dev This implementation does not throw for zero-address NFTs.
    mapping(uint256 => address) public ownerOf;

    /// @notice Gets the approved address for an NFT.
    /// @dev This implementation does not throw for zero-address queries.
    mapping(uint256 => address) public getApproved;

    /// @dev Checks for an owner if an address is an authorized operator.
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    // EIP-2981 collection-wide royalties information.
    RoyaltiesInfo internal _royaltiesInfo;

    // EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant _ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 private constant _ERC2981_METADATA_INTERFACE_ID = 0x2a55205a;

    /// @notice Instantiates a new ERC-721 contract.
    /// @param name_ The name of the NFT.
    /// @param symbol_ The abbreviated name of the NFT.
    constructor(
        string memory name_,
        string memory symbol_
    ) {
        name = name_;
        symbol = symbol_;
    }

    /// @inheritdoc IERC2981
    function royaltyInfo(
        uint256,
        uint256 salePrice
    ) external view returns (address, uint256) {
        RoyaltiesInfo memory royaltiesInfo = _royaltiesInfo;
        uint256 royalties = (salePrice * royaltiesInfo.royalties) / 10000;
        return (royaltiesInfo.receiver, royalties);
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  without performing any safety checks.
    /// @dev Existence of an NFT is inferred by having a non-zero owner address.
    ///  Transfers clear owner approvals, but `Approval` events are omitted.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The address of the new owner of the NFT to be transferred.
    /// @param id The id of the NFT being transferred.
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        if (from != ownerOf[id]) {
            revert OwnerInvalid();
        }

        if (
            msg.sender != from &&
            msg.sender != getApproved[id] &&
            !_operatorApprovals[from][msg.sender]
        ) {
            revert SenderUnauthorized();
        }

        if (to == address(0)) {
            revert ReceiverInvalid();
        }

        delete getApproved[id];

        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[id] = to;
        emit Transfer(from, to, id);
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The address of the new owner of the NFT to be transferred.
    /// @param id The id of the NFT being transferred.
    /// @param data Additional transfer data to pass to the receiving contract.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, data)
                !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert SafeTransferUnsupported();
        }
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The address of the new owner of the NFT to be transferred.
    /// @param id The id of the NFT being transferred.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, "")
                !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert SafeTransferUnsupported();
        }
    }

    /// @notice Sets approved address of NFT of id `id` to address `approved`.
    /// @param approved The new approved address for the NFT.
    /// @param id The id of the NFT to approve.
    function approve(address approved, uint256 id) public virtual {
        address owner = ownerOf[id];

        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
            revert SenderUnauthorized();
        }

        getApproved[id] = approved;
        emit Approval(owner, approved, id);
    }

    /// @notice Checks if `operator` is an authorized operator for `owner`.
    /// @param owner The address of the owner.
    /// @param operator The address for the owner's operator.
    /// @return True if `operator` is approved operator of `owner`, else false.
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    /// @notice Sets the operator for `msg.sender` to `operator`.
    /// @param operator The operator address that will manage the sender's NFTs
    /// @param approved Whether the operator is allowed to operate sender's NFTs
    function setApprovalForAll(address operator, bool approved) public {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Returns the metadata URI associated with the NFT of id `id`.
    /// @return A string URI pointing to metadata of the queried NFT.
    function tokenURI(uint256) public view virtual returns (string memory) {
        return "";
    }

    /// @notice Checks if interface of identifier `id` is supported.
    /// @param id The ERC-165 interface identifier.
    /// @return True if interface id `id` is supported, false otherwise.
    function supportsInterface(bytes4 id) public pure virtual returns (bool) {
        return
            id == _ERC165_INTERFACE_ID ||
            id == _ERC721_INTERFACE_ID ||
            id == _ERC721_METADATA_INTERFACE_ID ||
            id == _ERC2981_METADATA_INTERFACE_ID;
    }

    /// @notice Mints NFT of id `totalSupply + 1` to address `to`.
    /// @param creator Address to which NFT creation attribution is assigned.
    /// @param to Address receiving the minted NFT.
    function _mint(address creator, address to) internal {
        if (to == address(0)) {
            revert ReceiverInvalid();
        }

        unchecked {
            totalSupply++;
            balanceOf[to]++;
        }

        ownerOf[totalSupply] = to;
        emit Transfer(address(0), creator, totalSupply);
        emit Transfer(creator, to, totalSupply);
    }

    /// @notice Sets the royalty information for all NFTs in the collection.
    /// @param receiver Address which will receive token royalties.
    /// @param royalties Royalties amount, in bips.
    function _setRoyalties(address receiver, uint96 royalties) internal {
        if (royalties > 10000) {
            revert RoyaltiesTooHigh();
        }
        if (receiver == address(0)) {
            revert ReceiverInvalid();
        }
        _royaltiesInfo = RoyaltiesInfo(receiver, royalties);
    }

}
