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

    uint256 public constant MAX_WHITELIST_SIZE = 99;

    uint256 public constant MIN_DROP_SIZE = 1;
    uint256 public constant MAX_DROP_SIZE = 9999;

    uint256 public constant MIN_DROP_DELAY = 4 weeks;
    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    // An address who has permissions to mint RaritySociety tokens
    address public minter;

    // OpenSea's Proxy Registry
    IProxyRegistry public proxyRegistry;

    string public baseURI = "https://dopamine.xyz/";

    uint256 public dropSize;
    uint256 public dropDelay; 
    uint256 public whitelistSize;

    uint256 public dropEndIndex;
    uint256 public dropEndTime;

    // Maps drops to their provenance markers.
    mapping(uint256 => bytes32) private _dropProvenanceHashes;
    // Maps drops to their IPFS URIs.
    mapping(uint256 => string) private _dropURIs;
    // Maps drops to their whitelists (merkle roots).
    mapping(uint256 => bytes32) private _dropWhitelists;

    /// @notice Ending index for each drop (non-inclusive).
    uint256[] private _dropEndIndices;
    uint256 private _id;

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

    /// @notice Initializes the DopamintPass with the first drop created..
    /// @param minter_ The address which will control the NFT emissions.
    /// @param proxyRegistry_ The OpenSea proxy registry address.
    /// @param dropSize_ The number of DopamintPasses to issue for the next drop.
    /// @param dropDelay_ The minimum time in seconds to wait before a new drop.
    /// @dev Chain ID and domain separator are assigned here as immutables.
    constructor(
        address minter_,
        IProxyRegistry proxyRegistry_,
        uint256 dropSize_,
        uint256 dropDelay_,
        uint256 whitelistSize_,
        uint256 maxSupply_
    ) ERC721Checkpointable(NAME, SYMBOL, maxSupply_) {
		owner = msg.sender;
        minter = minter_;
        proxyRegistry = proxyRegistry_;

        setDropSize(dropSize_);
        setDropDelay(dropDelay_);
        setWhitelistSize(whitelistSize_);
    }

    /// @notice Mints a DopamintPass to the minter.
    function mint() public override onlyMinter returns (uint256) {
        if (_id >= dropEndIndex) {
            revert DropMaxCapacity();
        }
        return _mint(minter, _id++);
    }

    /// @notice Creates a new drop.
    /// @param whitelist A merkle root of the drop's whitelist.
    /// @param provenanceHash A provenance hash for the drop collection.
    function createDrop(bytes32 whitelist,  bytes32 provenanceHash) public onlyOwner {
        if (_id < dropEndIndex) {
            revert OngoingDrop();
        }
        if (block.timestamp < dropEndTime) {
            revert InsufficientTimePassed();
        }
        if (_id + dropSize > maxSupply) {
            revert DropMaxCapacity();
        }

        uint256 startIndex = _id;
        uint256 dropNumber = _dropEndIndices.length;

        _id += whitelistSize;
        dropEndIndex = startIndex + dropSize;
        dropEndTime = block.timestamp + dropDelay;

        _dropEndIndices.push(dropEndIndex);
        _dropProvenanceHashes[dropNumber] = provenanceHash;
        _dropWhitelists[dropNumber] = whitelist;

        emit DropCreated(dropNumber, startIndex, dropSize, whitelistSize, whitelist, provenanceHash);
    }

    /// @notice Set the minter of the contract
    function setMinter(address newMinter) external override onlyOwner {
        emit NewMinter(minter, newMinter);
        minter = newMinter;
    }
    
    /// @param newDropDelay The drops delay, in seconds.
    function setDropDelay(uint256 newDropDelay) public override onlyOwner {
        if (newDropDelay < MIN_DROP_DELAY || newDropDelay > MAX_DROP_DELAY) {
            revert InvalidDropDelay();
        }
        dropDelay = newDropDelay;
        emit DropDelaySet(dropDelay);
    }

    /// @notice Sets a new drop size `newDropSize`.
    /// @param newDropSize The number of NFTs to mint for the next drop.
    function setDropSize(uint256 newDropSize) public onlyOwner {
        if (newDropSize < MIN_DROP_SIZE || newDropSize > MAX_DROP_SIZE) {
            revert InvalidDropSize();
        }
        dropSize = newDropSize;
        emit DropSizeSet(dropSize);
    }

    /// @notice Sets a new whitelist size `newWhitelistSize`.
    /// @param newWhitelistSize The number of NFTs to whitelist for the next drop.
    function setWhitelistSize(uint256 newWhitelistSize) public onlyOwner {
        if (newWhitelistSize > MAX_WHITELIST_SIZE || newWhitelistSize > dropSize) {
            revert InvalidWhitelistSize();
        }
        whitelistSize = newWhitelistSize;
        emit WhitelistSizeSet(whitelistSize);
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
	
    /// @notice Sets the base URI.
    /// @param newBaseURI The base URI to set.
	function setBaseURI(string calldata newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
	}

    /// @notice Sets the IPFS URI `dropURI` for drop `dropId`.
    /// @param dropId The drop identifier to set.
	/// @param dropURI The drop URI to permanently set.
	function setDropURI(uint256 dropId, string calldata dropURI) public onlyOwner {
        uint256 numDrops = _dropEndIndices.length;
        if (dropId >= numDrops) {
            revert NonExistentDrop();
        }
        _dropURIs[dropId] = dropURI;
        emit DropURISet(dropId, dropURI);
	}


    /// @notice Checks if `operator` is an authorized operator for `owner`.
    /// @dev Ensures OS proxy is whitelisted for operating on behalf of owners.
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Claim `tokenId` for minting by presenting merkle proof `proof`.
    /// @param proof Merkle proof associated with the claim.
    /// @param tokenId Identifier of NFT being claimed.
    function claim(bytes32[] calldata proof, uint256 tokenId) external {
        bytes32 whitelist = _dropWhitelists[getDropId(tokenId)];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, tokenId));

        if (!_verify(whitelist, proof, leaf)) {
            revert InvalidProof();
        }

        _mint(msg.sender, tokenId);
    }

    /// @notice Verifies `leaf` is part of merkle tree rooted at `merkleRoot`.
    function _verify(
        bytes32 merkleRoot,
        bytes32[] memory proof,
        bytes32 leaf
    ) private view returns (bool) 
    {
        bytes32 hash = leaf;

        unchecked {
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
    }


    /// @notice Retrieves the token metadata URI for NFT of id `tokenId`.
    /// @dev Before drop finalization, the token URI for an NFT is equivalent to
    ///  {baseURI}/{id}, and once a drop is finalized, it may be replaced by an
    ///  IPFS link whose contents equate to the initially set provenance hash.
    /// @param tokenId The identifier of the NFT being queried.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf[tokenId] == address(0)) {
            revert NonExistentNFT();
        }

        string memory dropURI  = _dropURIs[getDropId(tokenId)];
		if (bytes(dropURI).length == 0) {
			dropURI = baseURI;
		}
		return string(abi.encodePacked(dropURI, _toString(tokenId)));
    }


	 function _toString(uint256 value) internal pure returns (string memory) {
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

