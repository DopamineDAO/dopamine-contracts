// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society ERC-721 token

pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { IRarityPass } from './interfaces/IRarityPass.sol';
import { ERC721CheckpointableUpgradeable } from './erc721/ERC721CheckpointableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC721Upgradeable } from './erc721/ERC721Upgradeable.sol';
import { IERC721Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import { IProxyRegistry } from './interfaces/IProxyRegistry.sol';

contract RarityPass is Initializable, ERC721CheckpointableUpgradeable, OwnableUpgradeable, IRarityPass {

    using StringsUpgradeable for uint256;

    uint256 public constant MAX_SUPPLY = 9999;

    uint256 public constant MIN_DROP_SIZE = 1;

    uint256 public constant MAX_DROP_SIZE = 100;

    uint256 public constant MIN_DROP_DELAY = 4 weeks;

    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    uint256 public constant TEAM_MINTS = 5;

    // An address who has permissions to mint RaritySociety tokens
    address public minter;

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

    mapping(uint256 => address) private dropDelegates;

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address minter_,
        IProxyRegistry proxyRegistry_
    ) external initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
        __ERC721Enumerable_init_unchained(name_, symbol_);
        __EIP712_init_unchained(name_, "1");
        __ERC721Checkpointable_init_unchained(name_);
        __Ownable_init_unchained();
        __RaritySocietyToken_init_unchained(minter_, proxyRegistry_);
    }

    function __RaritySocietyToken_init_unchained(address minter_, IProxyRegistry proxyRegistry_) internal initializer {
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

    function _createDrop(string calldata hash, uint256 dropSize) internal {
        require(!drop.initiated, "Drop already initiated");
        require(block.timestamp >= drop.endTime + dropDelay, "insufficient time has passed since the last drop");
        require(dropSize >= MIN_DROP_SIZE, "drop size too small");
        require(dropSize <= MAX_DROP_SIZE, "drop size too large");

        uint256 startIndex = totalSupply();
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
        require(_drop.endIndex == totalSupply() - 1, "Mints still remaining");
        drop.initiated = false;
        drop.endTime = block.timestamp;

        emit DropCompleted(drops++, drop.endTime);
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721Upgradeable, ERC721Upgradeable) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    // Mints initial tokens for the team
    function teamMint(address recipient) external onlyOwner {
        require(totalSupply() < TEAM_MINTS, "team minting completed");
        require(!drop.initiated, "drop has already started");
        for (uint256 i = 0; i < TEAM_MINTS; i++) {
            _mintTo(msg.sender, _currentId++);
            emit Mint(_currentId);
        }
    }

    /**
     * @notice Mint a rarity society.
     */
    function mint() public override onlyMinter returns (uint256) {
        require(totalSupply() < MAX_SUPPLY, "maximum supply reached");
        require(drop.initiated, "drop has not yet started");
        require(_currentId <= drop.endIndex, "drop capacity reached");
        return _mintTo(minter, _currentId++);
    }

    /**
     * @notice Burn a noun.
     */
    function burn(uint256 _tokenId) public override onlyMinter {
        _burn(_tokenId);
        emit Burn(_tokenId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');

        string memory dropURI = dropURIs[tokenId];
        if (bytes(dropURI).length == 0) {
            return super.tokenURI(tokenId);
        }

        // If no base URI, or both are set, return the drop URI
        return string(abi.encodePacked(dropURI, tokenId.toString()));
    }


    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
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
        _mint(owner(), _to, _tokenId);
        emit Mint(_tokenId);

        return _tokenId;
    }

    function getDropDelegate(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), 'query for nonexistent token');
        address delegate = dropDelegates[tokenId];
        return delegate == address(0) ? ownerOf(tokenId) : delegate;
    }

    function dropDelegate(address delegatee, uint256 tokenId) public {
        require(ERC721Upgradeable.ownerOf(tokenId) == msg.sender, 'gifting of unowned token');
        if (delegatee == address(0)) delegatee = msg.sender;
        _dropDelegate(delegatee, tokenId);
    }

    function _dropDelegate(address delegatee, uint256 tokenId) internal {
        dropDelegates[tokenId] = delegatee;
        emit DropDelegate(ERC721Upgradeable.ownerOf(tokenId), delegatee, tokenId);
    }

    // @notice Returns integer that represents the drop corresponding to tokenId
    function getTokenDrop(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token ID does not exist");
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

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._afterTokenTransfer(from, to, tokenId);

        // Clear drop delegates
        _dropDelegate(address(0), tokenId);
    }
}

