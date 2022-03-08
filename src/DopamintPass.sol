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

    uint256 public constant NUM_WHITELISTED = 20;

    uint256 public constant MIN_DROP_SIZE = 1;

    uint256 public constant MAX_DROP_SIZE = 100;

    uint256 public constant MIN_DROP_DELAY = 4 weeks;

    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    uint256 public constant TEAM_MINTS = 5;

    // An address who has permissions to mint RaritySociety tokens
    address public minter;

	bytes32 public merkleRoot;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // The internal token id tracker
    uint256 private _currentId;

    // OpenSea's Proxy Registry
    IProxyRegistry public proxyRegistry;

    // Number of completed drops
    uint256 public drops;

    // Minimum time to wait between drops
    uint256 public dropDelay; 

    // The active or most-recent drop
    Drop public drop;

    // Last ID of each NFT drop
    uint256[] private dropEndIndices;

    // Per-drop record of provenance
    mapping(uint256 => string) private dropHashes;
    mapping(uint256 => string) private dropURIs;
    mapping(uint256 => bool) private dropFixed;

    mapping(uint256 => uint256) private claimedBitMap;

    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OwnerOnly();
        }
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    constructor(
        address minter_,
        IProxyRegistry proxyRegistry_
    ) ERC721Checkpointable(NAME, SYMBOL, MAX_SUPPLY) {
		owner = msg.sender;
        minter = minter_;
        proxyRegistry = proxyRegistry_;
    }

    function setDropDelay(uint256 dropDelay_) external override onlyOwner {
        require(dropDelay_ >= MIN_DROP_DELAY, 'delay must exceed min');
        require(dropDelay_ <= MAX_DROP_DELAY, 'delay must not exceed max');
        dropDelay = dropDelay_;

        emit NewDropDelay(dropDelay);
    }

    function createDrop(string calldata hash, uint256 dropSize) external onlyMinter {
        _createDrop(hash, dropSize);
    }
    
    function completeDrop() external onlyMinter {
        _completeDrop();
    }

	function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return claimedBitMap[bucket] & mask != 0;
    }

    function claim(bytes32[] calldata merkleProof) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        (bool validProof, uint256 index) = _verify(merkleProof, leaf);

        if (!validProof) {
            revert InvalidProof();
        }

        if (isClaimed(index)) {
            revert AlreadyClaimed();
        }

        _setClaimed(index);
        emit Claimed(msg.sender);

        _mintTo(msg.sender, _currentId++);
    }

    function _setClaimed(uint256 index) private {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        claimedBitMap[bucket] |= mask;
    }

    function _verify(bytes32[] memory proof, bytes32 leaf) private view returns (bool, uint256) {
        bytes32 hash = leaf;
        uint256 index;

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

    function _createDrop(string calldata hash, uint256 dropSize) internal {
        require(!drop.initiated, "Drop already initiated");
        require(block.timestamp >= drop.endTime + dropDelay, "insufficient time has passed since the last drop");
        require(dropSize >= MIN_DROP_SIZE, "drop size too small");
        require(dropSize <= MAX_DROP_SIZE, "drop size too large");

        uint256 startIndex = totalSupply;
        require(startIndex + dropSize <= MAX_SUPPLY, "drop above maximum capacity");

        drop = Drop({
            endIndex: startIndex + dropSize - 1,
            initiated: true,
            endTime: 0
        });

        dropEndIndices.push(startIndex + dropSize - 1);
        dropHashes[drops] = hash;

        emit DropCreated(drops, startIndex, dropSize, block.timestamp, hash);
    }

    function _completeDrop() internal {
        Drop memory _drop = drop;

        require(_drop.initiated, "Drop already completed");
        require(_drop.endIndex == totalSupply - 1, "Mints still remaining");
        drop.initiated = false;
        drop.endTime = block.timestamp;

        emit DropCompleted(drops++, drop.endTime);
    }

    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function teamMint(address recipient) external onlyOwner {
        require(totalSupply < TEAM_MINTS, "team minting completed");
        require(!drop.initiated, "drop has already started");
        for (uint256 i = 0; i < TEAM_MINTS; i++) {
            _mintTo(msg.sender, _currentId++);
            emit Mint(_currentId);
        }
    }

    function mint() public override onlyMinter returns (uint256) {
        require(totalSupply < MAX_SUPPLY, "maximum supply reached");
        require(drop.initiated, "drop has not yet started");
        require(_currentId <= drop.endIndex, "drop capacity reached");
        return _mintTo(minter, _currentId++);
    }

    function burn(uint256 _tokenId) public override onlyMinter {
        _burn(_tokenId);
        emit Burn(_tokenId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        setBaseURI(baseURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');

        string memory dropURI = dropURIs[tokenId];
        if (bytes(dropURI).length == 0) {
            return super.tokenURI(tokenId);
        }

        // If no base URI, or both are set, return the drop URI
        return string(abi.encodePacked(dropURI, _toString(tokenId)));
    }


    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;

        emit ChangeMinter(_minter);
    }

    /**
     * @notice Lock the minter.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit LockMinter();
    }

    /**
     * @notice Mint a Noun with `nounId` to the provided `to` address.
     */
    function _mintTo(address _to, uint256 _tokenId) internal returns (uint256) {
        _mint(_to, _tokenId);
        emit Mint(_tokenId);

        return _tokenId;
    }

    // @notice Returns integer that represents the drop corresponding to tokenId
    function getTokenDrop(uint256 tokenId) public view returns (uint256) {
        // require(_exists(tokenId), "Token ID does not exist");
        for (uint256 i = 0; i < dropEndIndices.length; i++) {
            if (tokenId <= dropEndIndices[i]) {
                return i;
            }
        }
    }
	
	function getDropHash(uint256 dropId) external returns (string memory) {
		require(dropId <= drops, "drop has not yet started");
		return dropHashes[dropId];
	}

	function _setDropURI(uint256 dropId, string memory URI) public onlyOwner {
		require(dropId <= drops, "drop has not yet started");
		dropURIs[dropId] = URI;
	}


	function _setDropHash(uint256 dropId, string memory dropHash) public onlyOwner {
		require(dropId <= drops, "drop has not yet started");
		require(!dropFixed[dropId], "drop hashes no longer settable");
		dropHashes[dropId] = dropHash;
	}

	function _fixDrop(uint256 dropId) public onlyOwner {
		require(dropId <= drops, "drop has not yet started");
		require(!dropFixed[dropId], "drop URI setting privileges already revoked");
		dropFixed[dropId] = true;
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

