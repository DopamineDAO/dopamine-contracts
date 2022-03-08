// SPDX-License-Identifier: MIT

/// @title Minimal ERC721 Token Implementation

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '../errors.sol';
/// @title DθPΛM1NΞ ERC-721 base contract
/// @notice ERC-721 contract with metadata extension and maximum supply.
contract ERC721 is IERC721, IERC721Metadata {

    /// @notice Name of the NFT collection.
    string public name;

    /// @notice Abbreviated name of the NFT collection.
    string public symbol;

    /// @notice Total number of NFTs in circulation.
    uint256 public totalSupply;

    /// @notice Maximum allowed number of circulating NFTs.
	uint256 public immutable maxSupply;

    /// @notice Gets the number of NFTs owned by an address.
    /// @dev This implementation does not throw for 0-address queries.
    mapping(address => uint256) public balanceOf;

    /// @notice Gets the assigned owner of an address.
    mapping(uint256 => address) public ownerOf;

    /// @notice Gets the approved address for an NFT.
    mapping(uint256 => address) public getApproved;

    /// @notice Nonces for preventing replay attacks when signing.
    mapping(address => uint256) public nonces;

    /// @notice Checks for an owner if an address is an authorized operator.
    mapping(address => mapping(address => bool)) internal _operatorOf;

    /// @notice EIP-712 immutables for signing messages.
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    /// @notice EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant _ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    
    /// @notice Initialize the NFT collection contract.
    /// @param name_ Name of the NFT collection
    /// @param symbol_ Abbreviated name of the NFT collection.
    /// @param maxSupply_ Supply cap for the NFT collection
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) {
        name = name_;
        symbol = symbol_;
        maxSupply = maxSupply_;

        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  without performing any safety checks.
    /// @param from The address of the current owner of the transferred NFT.
    /// @param to The address of the new owner of the transferred NFT.
    /// @param id The NFT being transferred.
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        _transferFrom(from, to, id);
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @param from The address of the current owner of the transferred NFT.
    /// @param to The address of the new owner of the transferred NFT.
    /// @param id The NFT being transferred.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        _transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert InvalidReceiver();
        }
    }

    /// @notice Equivalent to preceding function with empty `data`.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        _transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert InvalidReceiver();
        }
    }

    /// @notice Sets the approved address of NFT of id `id` to `approved`.
    /// @param approved The new approved address for the NFT
    /// @param id The id of the NFT to approve
    function approve(address approved, uint256 id) public virtual {
        address owner = ownerOf[id];

        if (msg.sender != owner && !_operatorOf[owner][msg.sender]) {
            revert UnauthorizedSender();
        }

        getApproved[id] = approved;
        emit Approval(owner, approved, id);
    }

    /// @notice Checks if `operator` is an authorized operator for `owner`.
    /// @param owner Address of the owner.
    /// @param operator Address for the owner's operator.
    /// @return true if `operator` is approved operator of `owner`, else false.
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorOf[owner][operator];
    }

    /// @notice Sets the operator for `msg.sender` to `operator`.
    /// @param operator The operator address that will manage the sender's NFTs
    /// @param approved Whether the operator is allowed to operate sender's NFTs
    function setApprovalForAll(address operator, bool approved) public virtual {
        _operatorOf[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Returns the token URI associated with the token of id `id`.
    function tokenURI(uint256 id) public view virtual returns (string memory) {
        return "";
    }

    /// @notice Checks if interface of identifier `interfaceId` is supported.
    /// @param interfaceId ERC-165 identifier
    /// @return `true` if `interfaceId` is supported, `false` otherwise.
    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == _ERC165_INTERFACE_ID ||
            interfaceId == _ERC721_INTERFACE_ID ||
            interfaceId == _ERC721_METADATA_INTERFACE_ID;
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`.
    /// @dev Existence of an NFT is inferred by having a non-zero owner address.
    ///  To save gas, use Transfer events to track Approval clearances.
    /// @param from The address of the owner of the NFT.
    /// @param to The address of the new owner of the NFT.
    /// @param id The id of the NFT being transferred.
    function _transferFrom(address from, address to, uint256 id) internal virtual {
        if (from != ownerOf[id]) {
            revert InvalidOwner();
        }

        if (
            msg.sender != from &&
            msg.sender != getApproved[id] &&
            !_operatorOf[from][msg.sender]
        ) {
            revert UnauthorizedSender();
        }

        if (to == address(0)) {
            revert ZeroAddressReceiver();
        }

        _beforeTokenTransfer(from, to, id);

        delete getApproved[id];

        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[id] = to;
        emit Transfer(from, to, id);
    }

    /// @notice Mints NFT of id `id` to address `to`.
    /// @dev Assumes `maxSupply` < `type(uint256).max` to save on gas. 
    /// @param to Address receiving the minted NFT.
    /// @param id identifier of the NFT being minted.
    function _mint(address to, uint256 id) internal virtual {
        if (to == address(0)) {
            revert ZeroAddressReceiver();
        }
        if (ownerOf[id] != address(0)) {
            revert DuplicateMint();
        }

        _beforeTokenTransfer(address(0), to, id);

        unchecked {
            totalSupply++;
            balanceOf[to]++;
        }
        if (totalSupply > maxSupply) {
            revert SupplyMaxCapacity();
        }
        ownerOf[id] = to;
        emit Transfer(address(0), to, id);
    }

	/// @notice Burns NFT of id `id`.
    /// @param id Identifier of the NFT being burned
    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        if (owner == address(0)) {
            revert NonExistentNFT();
        }

        _beforeTokenTransfer(owner, address(0), id);

        unchecked {
            totalSupply--;
            balanceOf[owner]--;
        }

        delete ownerOf[id];
        emit Transfer(owner, address(0), id);
    }

    /// @notice Pre-transfer hook for adding additional functionality.
    /// @param from The address of the owner of the NFT.
    /// @param to The address of the new owner of the NFT.
    /// @param id The id of the NFT being transferred.
    function _beforeTokenTransfer(address from, address to, uint256 id) internal virtual {
    }

	/// @notice Generates an EIP-712 domain separator for an ERC-721.
    /// @return A 256-bit domain separator.
    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

	/// @notice Returns an EIP-712 encoding of structured data `structHash`.
    /// @param structHash The structured data to be encoded and signed.
    /// @return A bytestring suitable for signing in accordance to EIP-712.
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    /// @notice Returns the domain separator tied to the contract.
    /// @dev Recreated if chain id changes, otherwise cached value is used.
    /// @return 256-bit domain separator tied to this contract.
    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator();
        }
    }

}
