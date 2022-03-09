// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import './errors.sol';

import { IDopamintPass } from './interfaces/IDopamintPass.sol';
import { ERC721 } from './erc721/ERC721.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { ERC721Checkpointable } from './erc721/ERC721Checkpointable.sol';
import { IProxyRegistry } from './interfaces/IProxyRegistry.sol';

contract DopamintPass is ERC721Checkpointable, IDopamintPass {

    address owner;

    string public constant NAME = "Dopamint Pass";

    string public constant SYMBOL = "DOPE";

    uint256 public constant MAX_SUPPLY = 9999;

    uint256 public constant NUM_WHITELISTED = 33;

    uint256 public constant MIN_DROP_SIZE = 1;
    uint256 public constant MAX_DROP_SIZE = 999;

    uint256 public constant MIN_DROP_DELAY = 4 weeks;

    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    uint256 public constant TEAM_MINTS = 5;

    // An address who has permissions to mint RaritySociety tokens
    address public minter;

    /// @notice Address that collects gifted DopamintPasses.
    address public reserve = address(this);

	bytes32 public merkleRoot;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // OpenSea's Proxy Registry
    IProxyRegistry public proxyRegistry;

    string public baseURI = "https://dopamine.xyz";

    uint256 public dropSize;
    uint256 public dropDelay; 

    /// @notice Ending index for each drop (non-inclusive).
    uint256[] private _dropEndIndices;

    uint256 public dropEndIndex;
    uint256 public dropEndTime;

    // Maps drops to their provenance markers.
    mapping(uint256 => bytes32) private _dropProvenanceHashes;
    // Maps drops to their IPFS hashes.
    mapping(uint256 => bytes32) private _dropIPFSHashes;

    mapping(uint256 => uint256) private claimedBitMap;

    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    /// @notice Modifier to restrict calls to owner only.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OwnerOnly();
        }
        _;
    }

    /// @notice Modifier to restrict calls to minter only.
    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert MinterOnly();
        }
        _;
    }

    constructor(
        address minter_,
        IProxyRegistry proxyRegistry_,
        address reserve_,
        bytes32 provenanceHash
    ) ERC721Checkpointable(NAME, SYMBOL, MAX_SUPPLY) {
		owner = msg.sender;
        minter = minter_;
        proxyRegistry = proxyRegistry_;

        createDrop(NUM_WHITELISTED, provenanceHash);

        reserve = reserve_;
    }

    /// @notice Mints a DopamintPass to the minter.
    function mint() public override onlyMinter returns (uint256) {
        if (totalSupply >= dropEndIndex) {
            revert DropMaxCapacity();
        }
        return _mint(minter, totalSupply);
    }

    /// @notice Set the minter of the contract
    function setMinter(address newMinter) external override onlyOwner whenMinterNotLocked {
        emit NewMinter(minter, newMinter);
        minter = newMinter;
    }

    /// @notice Lock the minter, permanently fixing the emissions source.
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;
        emit MinterLocked();
    }

    /// @notice Creates a new drop of size `dropSize`.
    /// @param numGifted Number of DopamintPasses to mint to the reserve.
    /// @param provenanceHash A provenance hash for the drop collection.
    function createDrop(uint256 numGifted, bytes32 provenanceHash) public onlyOwner {
        if (totalSupply < dropEndIndex) {
            revert OngoingDrop();
        }
        if (block.timestamp < dropEndTime) {
            revert InsufficientTimePassed();
        }
        if (totalSupply + dropSize > MAX_SUPPLY || numGifted > dropSize) {
            revert DropMaxCapacity();
        }

        uint256 startIndex = totalSupply;
        uint256 dropNumber = _dropEndIndices.length;

        dropEndIndex = startIndex + dropSize;
        dropEndTime = block.timestamp + dropDelay;

        _dropEndIndices.push(dropEndIndex);
        _dropProvenanceHashes[dropNumber] = provenanceHash;

        emit DropCreated(dropNumber, startIndex, dropSize, provenanceHash);
    }
    
    /// @param newDropDelay The drops delay, in seconds.
    function setDropDelay(uint256 newDropDelay) external override onlyOwner {
        if (newDropDelay < MIN_DROP_DELAY || newDropDelay > MAX_DROP_DELAY) {
            revert InvalidDropDelay();
        }
        dropDelay = newDropDelay;
        emit DropDelaySet(dropDelay);
    }

    /// @notice Sets a new drop size `newDropSize`.
    /// @param newDropSize The number of NFTs to mint for the next drop.
    function setDropSize(uint256 newDropSize) external onlyOwner {
        if (newDropSize < MIN_DROP_SIZE || newDropSize > MAX_DROP_SIZE) {
            revert InvalidDropSize();
        }
        dropSize = newDropSize;
        emit DropSizeSet(dropSize);
    }

    /// @notice Return the drop number of the DopamintPass with id `tokenId`.
    /// @param tokenId Identifier of the DopamintPass being queried.
    function getDropId(uint256 tokenId) public view returns (uint256) {
        if (ownerOf[tokenId] == address(0)) {
            revert NonExistentNFT();
        }

        for (uint256 i = 0; i < _dropEndIndices.length; i++) {
            if (tokenId < _dropEndIndices[i]) {
                return i;
            }
        }
    }
	
	// function setDropIPFSHash(uint256 dropId, bytes32 hash) public onlyOwner {
	// 	require(dropId <= drops, "drop has not yet started");
	// 	dropURIs[dropId] = URI;
	// }


	// function _fixDrop(uint256 dropId) public onlyOwner {
	// 	require(dropId <= drops, "drop has not yet started");
	// 	require(!dropFixed[dropId], "drop URI setting privileges already revoked");
	// 	dropFixed[dropId] = true;
	// }



    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }



	function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return claimedBitMap[bucket] & mask != 0;
    }

    function claim(bytes32[] calldata merkleProof, uint256 tokenId) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, tokenId));
        (bool validProof, uint256 index) = _verify(merkleProof, leaf);

        if (!validProof) {
            revert InvalidProof();
        }

        if (isClaimed(index)) {
            revert AlreadyClaimed();
        }

        _setClaimed(index);
        emit Claimed(msg.sender, tokenId);

        _transferFrom(address(this), msg.sender, tokenId);
    }

    function _setClaimed(uint256 index) private {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        claimedBitMap[bucket] |= mask;
    }

    function _verify(bytes32[] memory proof, bytes32 leaf) private view returns (bool, uint256 index) {
        bytes32 hash = leaf;

        unchecked {
            for (uint256 i = 0; i < proof.length; i++) {
                index *= 2;
                bytes32 proofElement = proof[i];
                if (hash <= proofElement) {
                    hash = keccak256(abi.encodePacked(hash, proofElement));
                } else {
                    hash = keccak256(abi.encodePacked(proofElement, hash));
                    index += 1;
                }
            }
            return (hash == merkleRoot, index);
        }
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf[tokenId] == address(0)) {
            revert NonExistentNFT();
        }

        uint256 dropId = getDropId(tokenId);

        // If no base URI, or both are set, return the drop URI
        return string(abi.encodePacked(dropId, _toString(tokenId)));
    }


	 function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

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

