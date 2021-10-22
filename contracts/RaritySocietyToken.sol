// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society ERC-721 token

pragma solidity ^0.8.9;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IRaritySocietyToken } from './interfaces/IRaritySocietyToken.sol';
import { ERC721Checkpointable } from './erc721/ERC721Checkpointable.sol';
import { ERC721 } from './erc721/ERC721.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { IProxyRegistry } from './interfaces/IProxyRegistry.sol';

contract RaritySocietyToken is IRaritySocietyToken, Ownable, ERC721Checkpointable {
    // An address who has permissions to mint RaritySociety tokens
    address public minter;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // The internal token id tracker
    uint256 private _currentId;

    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

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

    constructor(
        address _minter,
        IProxyRegistry _proxyRegistry
    ) ERC721('Rarity Society', 'RARITY') ERC721Checkpointable('Rarity Society') {
        minter = _minter;
        proxyRegistry = _proxyRegistry;
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Mint a rarity society.
     */
    function mint() public override onlyMinter returns (uint256) {
        return _mintTo(minter, _currentId++);
    }

    /**
     * @notice Burn a noun.
     */
    function burn(uint256 _tokenId) public override onlyMinter {
        _burn(_tokenId);
        emit Burn(_tokenId);
    }


    /**
     * @notice Base URI for computing token metadata URI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return 'https://raritysociety.com/';
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
}
