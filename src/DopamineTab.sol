// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./Errors.sol";
import { IDopamineTab } from "./interfaces/IDopamineTab.sol";
import { IOpenSeaProxyRegistry } from "./interfaces/IOpenSeaProxyRegistry.sol";
import { ERC721 } from "./erc721/ERC721.sol";
import { ERC721Votable } from "./erc721/ERC721Votable.sol";

/// @title Dopamine DAO ERC-721 Membership Tab
/// @notice DopamineTab holders are first-class members of the Dopamine DAO.
///  The tabs are minted through drops of varying sizes and durations, and
///  each drop features a separate set of NFT metadata. These parameters are 
///  configurable by the admin address, with emissions controlled by the minter
///  address. A drop is "completed" once all non-whitelisted tabs are minted.
/// @dev It is intended for the admin to be the team multi-sig, with the minter
///  being the Dopamine DAO Auction House address (minter controls emissions).
contract DopamineTab is ERC721Votable, IDopamineTab {

    /// @notice The maximum number of tabs that may be whitelisted per drop.
    uint256 public constant MAX_WL_SIZE = 99;

    /// @notice The minimum number of tabs that can be minted for a drop.
    uint256 public constant MIN_DROP_SIZE = 1;

    /// @notice The maximum number of tabs that can be minted for a drop.
    uint256 public constant MAX_DROP_SIZE = 9999;

    /// @notice The minimum delay to wait between creations of drops.
    uint256 public constant MIN_DROP_DELAY = 4 weeks;

    /// @notice The maximum delay to wait between creations of drops.
    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    /// @notice The address administering drop creation, sizing, and scheduling.
    address public admin;

    /// @notice The address responsible for controlling tab emissions.
    address public minter;

    /// @notice The OS registry address - whitelisted for gasless OS approvals.
    IOpenSeaProxyRegistry public proxyRegistry;

    /// @notice The URI each tab initially points to for metadata resolution.
    /// @dev Before drop completion, `tokenURI()` resolves to "{baseUri}/{id}".
    string public baseUri = "https://dopamine.xyz/";

    /// @notice The minimum time to wait in seconds between drop creations.
    uint256 public dropDelay; 

    /// @notice The current drop's ending tab id (exclusive boundary).
    uint256 public dropEndIndex;

    /// @notice The time at which a new drop can start (if last drop completed).
    uint256 public dropEndTime;

    /// @notice The number of tabs for each drop (includes those whitelisted).
    uint256 public dropSize;

    /// @notice The number of tabs to allocate for whitelisting for each drop.
    uint256 public whitelistSize;

    /// @notice Maps a drop to its provenance hash.
    mapping(uint256 => bytes32) public dropProvenanceHash;

    /// @notice Maps a drop to its finalized IPFS / Arweave tab metadata URI.
    mapping(uint256 => string) public dropURI;

    /// @notice Maps a drop to its whitelist (merkle tree root).
    mapping(uint256 => bytes32) public dropWhitelist;

    /// @dev Maps a drop id to its ending tab id (exclusive boundary).
    uint256[] private _dropEndIndices;

    /// @dev An internal tracker for the id of the next tab to mint.
    uint256 private _id;

    /// @notice Restricts a function call to address `minter`.
    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert MinterOnly();
        }
        _;
    }

    /// @notice Restricts a function call to address `admin`.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    /// @notice Initializes the membership tab with specified drop settings.
    /// @param minter_        The address which will control tab emissions.
    /// @param proxyRegistry_ The OS proxy registry address.
    /// @param dropSize_      The number of tabs to issue for each drop.
    /// @param dropDelay_     The minimum delay to wait between drop creations.
    /// @dev `admin` is intended to eventually switch to the Dopamine DAO proxy.
    constructor(
        address minter_,
        IOpenSeaProxyRegistry proxyRegistry_,
        uint256 dropSize_,
        uint256 dropDelay_,
        uint256 whitelistSize_,
        uint256 maxSupply_
    ) ERC721Votable("DopamineTab", "DOPE", maxSupply_) {
		admin = msg.sender;
        minter = minter_;
        proxyRegistry = proxyRegistry_;

        setDropSize(dropSize_);
        setDropDelay(dropDelay_);
        setWhitelistSize(whitelistSize_);
    }

    /// @inheritdoc IDopamineTab
    function mint() external onlyMinter returns (uint256) {
        if (_id >= dropEndIndex) {
            revert DropMaxCapacity();
        }
        return _mint(minter, _id++);
    }

    /// @inheritdoc IDopamineTab
    function claim(bytes32[] calldata proof, uint256 id) external {
        bytes32 whitelist = dropWhitelist[dropId(id)];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, id));

        if (!_verify(whitelist, proof, leaf)) {
            revert ProofInvalid();
        }

        _mint(msg.sender, id);
    }

    /// @inheritdoc IDopamineTab
    function createDrop(bytes32 whitelist,  bytes32 provenanceHash)
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

        _id += whitelistSize;
        dropEndIndex = startIndex + dropSize;
        _dropEndIndices.push(dropEndIndex);

        dropEndTime = block.timestamp + dropDelay;
        dropProvenanceHash[dropNumber] = provenanceHash;
        dropWhitelist[dropNumber] = whitelist;

        emit DropCreated(
            dropNumber,
            startIndex,
            dropSize,
            whitelistSize,
            whitelist,
            provenanceHash
        );
    }

    /// @inheritdoc IDopamineTab
    /// @dev This function only reverts for non-existent drops. The drop id will
    ///  still be returned for an unminted tab belonging to a created drop.
    function dropId(uint256 id) public view returns (uint256) {
        for (uint256 i = 0; i < _dropEndIndices.length; i++) {
            if (id  < _dropEndIndices[i]) {
                return i;
            }
        }
        revert DropNonExistent();
    }
	
    /// @inheritdoc IDopamineTab
    function contractURI() external view returns (string memory)  {
        return string(abi.encodePacked(baseUri, "metadata"));
    }

    /// @inheritdoc ERC721
    /// @dev Before drop completion, the token URI for tab of id `id` defaults
    ///  to {baseUri}/{id}. Once the drop completes, it is replaced by an IPFS / 
    ///  Arweave URI, and `tokenURI()` will resolve to {dropURI[dropId]}/{id}.
    ///  This function reverts if the queried tab of id `id` does not exist.
    /// @param id The id of the NFT being queried.
    function tokenURI(uint256 id) 
        public 
        view 
        virtual 
        override(ERC721) 
        returns (string memory) 
    {
        if (ownerOf[id] == address(0)) {
            revert TokenNonExistent();
        }

        string memory uri = dropURI[dropId(id)];
		if (bytes(uri).length == 0) {
			uri = baseUri;
		}
		return string(abi.encodePacked(uri, _toString(id)));
    }


    /// @dev Ensures OS proxy is whitelisted for operating on behalf of owners.
    /// @inheritdoc ERC721
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

    /// @inheritdoc IDopamineTab
    function setMinter(address newMinter) external onlyAdmin {
        emit MinterChanged(minter, newMinter);
        minter = newMinter;
    }

    /// @inheritdoc IDopamineTab
    function setAdmin(address newAdmin) external onlyAdmin {
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    /// @inheritdoc IDopamineTab
	function setBaseURI(string calldata newBaseURI) external onlyAdmin {
        baseUri = newBaseURI;
        emit BaseURISet(newBaseURI);
	}

    /// @inheritdoc IDopamineTab
	function setDropURI(uint256 id, string calldata dropUri)
        external 
        onlyAdmin 
    {
        uint256 numDrops = _dropEndIndices.length;
        if (id >= numDrops) {
            revert DropNonExistent();
        }
        dropURI[id] = dropUri;
        emit DropURISet(id, dropUri);
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
            newDropSize < whitelistSize ||
            newDropSize < MIN_DROP_SIZE || 
            newDropSize > MAX_DROP_SIZE
        ) {
            revert DropSizeInvalid();
        }
        dropSize = newDropSize;
        emit DropSizeSet(dropSize);
    }

    /// @inheritdoc IDopamineTab
    function setWhitelistSize(uint256 newWhitelistSize) public onlyAdmin {
        if (newWhitelistSize > MAX_WL_SIZE || newWhitelistSize > dropSize) {
            revert DropAllowlistOverCapacity();
        }
        whitelistSize = newWhitelistSize;
        emit WhitelistSizeSet(whitelistSize);
    }

    /// @dev Checks whether `leaf` is part of merkle tree rooted at `merkleRoot`
    ///  using proof `proof`. Merkle tree generation and proof construction is
    ///  done using the following JS library: github.com/miguelmota/merkletreejs
    /// @param merkleRoot The hexlified merkle root as a bytes32 data type.
    /// @param proof      The abi-encoded proof formatted as a bytes32 array.
    /// @param leaf       The leaf node being checked (uses keccak-256 hashing).
    /// @return True if `leaf` is in `merkleRoot`-rooted tree, false otherwise.
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
