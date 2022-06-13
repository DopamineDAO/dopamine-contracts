// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "../interfaces/Errors.sol";
import { IDopamineTab } from "../interfaces/IDopamineTab.sol";
import { IOpenSeaProxyRegistry } from "../interfaces/IOpenSeaProxyRegistry.sol";

import { ERC721 } from "../erc721/ERC721.sol";
import { ERC721Votable } from "../erc721/ERC721Votable.sol";

/// @title Dopamine Membership Tab
/// @notice Tab holders are first-class members of the Dopamine metaverse.
///  The tabs are minted through seasonal drops of varying sizes and durations,
///  with each drop featuring different sets of attributes. Drop parameters are
///  configurable by the admin address, with emissions controlled by the minter
///  address. A drop is completed once all non-allowlisted tabs are minted.
/// @dev It is intended for the admin to be the team multi-sig, with the minter
///  being the Dopamine Auction House address (minter controls emissions).
contract DopamineTab is ERC721Votable, IDopamineTab {

    /// @notice The maximum number of tabs that may be allowlisted per drop.
    uint256 public constant MAX_WL_SIZE = 99;

    /// @notice The minimum number of tabs that can be minted for a drop.
    uint256 public constant MIN_DROP_SIZE = 1;

    /// @notice The maximum number of tabs that can be minted for a drop.
    uint256 public constant MAX_DROP_SIZE = 9999;

    /// @notice The minimum delay required to wait between creations of drops.
    uint256 public constant MIN_DROP_DELAY = 4 weeks;

    /// @notice The maximum delay required to wait between creations of drops.
    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    /// @notice The address administering drop creation, sizing, and scheduling.
    address public admin;

    /// @notice The address responsible for controlling tab emissions.
    address public minter;

    /// @notice The OS registry address - allowlisted for gasless OS approvals.
    IOpenSeaProxyRegistry public proxyRegistry;

    /// @notice The URI each tab initially points to for metadata resolution.
    /// @dev Before drop completion, `tokenURI()` resolves to "{baseURI}/{id}".
    string public baseURI;

    /// @notice The minimum time to wait in seconds between drop creations.
    uint256 public dropDelay;

    /// @notice The current drop's ending tab id (exclusive boundary).
    uint256 public dropEndIndex;

    /// @notice The time at which a new drop can start (if last drop completed).
    uint256 public dropEndTime;

    /// @notice The number of tabs for each drop (includes those allowlisted).
    uint256 public dropSize;

    /// @notice The number of tabs to allocate for allowlisting for each drop.
    uint256 public allowlistSize;

    /// @notice Maps a drop to its provenance hash.
    mapping(uint256 => bytes32) public dropProvenanceHash;

    /// @notice Maps a drop to its finalized IPFS / Arweave tab metadata URI.
    mapping(uint256 => string) public dropURI;

    /// @notice Maps a drop to its allowlist (merkle tree root).
    mapping(uint256 => bytes32) public dropAllowlist;

    /// @dev Maps a drop id to its ending tab id (exclusive boundary).
    uint256[] private _dropEndIndices;

    /// @dev An internal tracker for the id of the next tab to mint.
    uint256 private _id;

    /// @dev Restricts a function call to address `minter`.
    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert MinterOnly();
        }
        _;
    }

    /// @dev Restricts a function call to address `admin`.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    /// @notice Initializes the membership tab with the specified drop settings.
    /// @param minter_ The address which will control tab emissions.
    /// @param proxyRegistry_ The OS proxy registry address.
    /// @param dropSize_ The number of tabs to issue for each drop.
    /// @param dropDelay_ The minimum delay to wait between drop creations.
    constructor(
        string memory baseURI_,
        address minter_,
        IOpenSeaProxyRegistry proxyRegistry_,
        uint256 dropSize_,
        uint256 dropDelay_,
        uint256 allowlistSize_,
        uint256 maxSupply_
    ) ERC721Votable("Dopamine Tabs", "TAB", maxSupply_) {
        admin = msg.sender;
        emit AdminChanged(address(0), admin);

        minter = minter_;
        emit MinterChanged(address(0), minter);

        proxyRegistry = proxyRegistry_;

        baseURI = baseURI_;
        emit BaseURISet(baseURI);

        setDropSize(dropSize_);
        setDropDelay(dropDelay_);
        setAllowlistSize(allowlistSize_);
    }

    /// @inheritdoc IDopamineTab
    function contractURI() external view returns (string memory)  {
        return string(abi.encodePacked(baseURI, "contract"));
    }

    /// @inheritdoc ERC721
    /// @dev Before drop completion, the token URI for tab of id `id` defaults
    ///  to {baseURI}/{id}. Once the drop completes, it is replaced by an IPFS /
    ///  Arweave URI, and `tokenURI()` will resolve to {dropURI[dropId]}/{id}.
    ///  This function reverts if the queried tab of id `id` does not exist.
    /// @param id The id of the NFT being queried.
    function tokenURI(uint256 id)
        external
        view
        override(ERC721)
        returns (string memory)
    {
        if (ownerOf[id] == address(0)) {
            revert TokenNonExistent();
        }

        string memory uri = dropURI[dropId(id)];
        if (bytes(uri).length == 0) {
            uri = baseURI;
        }
        return string(abi.encodePacked(uri, _toString(id)));
    }


    /// @dev Ensures OS proxy is allowlisted for operating on behalf of owners.
    /// @inheritdoc ERC721
    function isApprovedForAll(address owner, address operator)
        external
        view
        override
        returns (bool)
    {
        return
            proxyRegistry.proxies(owner) == operator ||
            _operatorApprovals[owner][operator];
    }

    /// @inheritdoc IDopamineTab
    function mint() external onlyMinter returns (uint256) {
        if (_id >= dropEndIndex) {
            revert DropMaxCapacity();
        }
        return _mint(minter, _id++);
    }


    /// @inheritdoc IDopamineTab
    function burn(uint256 id) external {
        if (msg.sender != ownerOf[id]) {
            revert SenderUnauthorized();
        }
        _burn(id);
    }

    /// @inheritdoc IDopamineTab
    function claim(bytes32[] calldata proof, uint256 id) external {
        bytes32 allowlist = dropAllowlist[dropId(id)];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, id));

        if (!_verify(allowlist, proof, leaf)) {
            revert ProofInvalid();
        }

        _mint(msg.sender, id);
    }

    /// @inheritdoc IDopamineTab
    function createDrop(bytes32 allowlist,  bytes32 provenanceHash)
        external
        onlyAdmin
    {
        if (_id < dropEndIndex) {
            revert DropOngoing();
        }
        if (block.timestamp < dropEndTime) {
            revert DropTooEarly();
        }
        if (_id + dropSize > maxSupply) {
            revert DropMaxCapacity();
        }

        uint256 startIndex = _id;
        uint256 dropNumber = _dropEndIndices.length;

        _id += allowlistSize;
        dropEndIndex = startIndex + dropSize;
        _dropEndIndices.push(dropEndIndex);

        dropEndTime = block.timestamp + dropDelay;
        dropProvenanceHash[dropNumber] = provenanceHash;
        dropAllowlist[dropNumber] = allowlist;

        emit DropCreated(
            dropNumber,
            startIndex,
            dropSize,
            allowlistSize,
            allowlist,
            provenanceHash
        );
    }

    /// @inheritdoc IDopamineTab
    function setMinter(address newMinter) external onlyAdmin {
        if (newMinter == address(0)) {
            revert AddressInvalid();
        }
        emit MinterChanged(minter, newMinter);
        minter = newMinter;
    }

    /// @inheritdoc IDopamineTab
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert AddressInvalid();
        }
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    /// @inheritdoc IDopamineTab
    function setDropURI(uint256 id, string calldata uri)
        external
        onlyAdmin
    {
        uint256 numDrops = _dropEndIndices.length;
        if (id >= numDrops) {
            revert DropNonExistent();
        }
        dropURI[id] = uri;
        emit DropURISet(id, uri);
    }

    /// @inheritdoc IDopamineTab
    function setBaseURI(string calldata newBaseURI) external onlyAdmin {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }


    /// @inheritdoc IDopamineTab
    function setDropDelay(uint256 newDropDelay) public override onlyAdmin {
        if (newDropDelay < MIN_DROP_DELAY || newDropDelay > MAX_DROP_DELAY) {
            revert DropDelayInvalid();
        }
        dropDelay = newDropDelay;
        emit DropDelaySet(dropDelay);
    }

    /// @inheritdoc IDopamineTab
    function setDropSize(uint256 newDropSize) public onlyAdmin {
        if (
            newDropSize < allowlistSize ||
            newDropSize < MIN_DROP_SIZE ||
            newDropSize > MAX_DROP_SIZE
        ) {
            revert DropSizeInvalid();
        }
        dropSize = newDropSize;
        emit DropSizeSet(dropSize);
    }

    /// @inheritdoc IDopamineTab
    function setAllowlistSize(uint256 newAllowlistSize) public onlyAdmin {
        if (newAllowlistSize > MAX_WL_SIZE || newAllowlistSize > dropSize) {
            revert DropAllowlistOverCapacity();
        }
        allowlistSize = newAllowlistSize;
        emit AllowlistSizeSet(allowlistSize);
    }

    /// @inheritdoc IDopamineTab
    function dropId(uint256 id) public view returns (uint256) {
        for (uint256 i = 0; i < _dropEndIndices.length; i++) {
            if (id  < _dropEndIndices[i]) {
                return i;
            }
        }
        revert DropNonExistent();
    }

    /// @dev Checks whether `leaf` is part of merkle tree rooted at `merkleRoot`
    ///  using proof `proof`. Merkle tree generation and proof construction is
    ///  done using the following JS library: github.com/miguelmota/merkletreejs
    /// @param merkleRoot The hexlified merkle root as a bytes32 data type.
    /// @param proof The abi-encoded proof formatted as a bytes32 array.
    /// @param leaf The leaf node being checked (uses keccak-256 hashing).
    /// @return True if `leaf` is in `merkleRoot`-rooted tree, False otherwise.
    function _verify(
        bytes32 merkleRoot,
        bytes32[] memory proof,
        bytes32 leaf
    ) private pure returns (bool)
    {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (hash <= proofElement) {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            } else {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            }
        }
        return hash == merkleRoot;
    }

    /// @dev Converts a uint256 into a string.
    function _toString(uint256 value) private pure returns (string memory) {
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
