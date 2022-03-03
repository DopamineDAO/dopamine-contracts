// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society ERC-721 token

pragma solidity ^0.8.9;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import { ERC721Checkpointable } from '../../erc721/ERC721Checkpointable.sol';
import { ERC721 } from '../../erc721/ERC721.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract MockRaritySocietyDAOToken is ERC721Checkpointable, Ownable {

    uint256 public maxSupply;

    address public minter;

    uint256 private _currentId;

    string private constant name_ = 'Rarity Society';
    string private constant symbol_ = 'RARITY';

    constructor(address _minter, uint256 _maxSupply) ERC721Checkpointable(name_, symbol_) {
        minter = _minter;
        maxSupply = _maxSupply;
    }

    /**
     * @notice Mint a rarity society.
     */
    function mint() public returns (uint256) {
        require(totalSupply() < maxSupply, "max supply reached");
        return mintToken(_currentId++);
    }

    function mintToken(uint256 tokenId) public returns (uint256) {
        _mint(owner(), minter, tokenId);
        return tokenId;
    }

    function mintTokenTo(uint256 tokenId, address to) public returns (uint256) {
        _mint(owner(), to, tokenId);
        return tokenId;
    }

    function burn(uint256 _tokenId) public {
        _burn(_tokenId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function testSafe32(uint256 n) public pure returns (uint32) {
        return _safe32(n);
    }

}

