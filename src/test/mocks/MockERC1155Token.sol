// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society ERC-1155 token

pragma solidity ^0.8.9;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ERC1155 } from '../../erc1155/ERC1155.sol';

contract MockERC1155Token is ERC1155, Ownable {

    uint256 public maxSupply;

    address public minter;

    uint256 private _currentId;

    constructor(address _minter, uint256 _maxSupply) {
        minter = _minter;
        maxSupply = _maxSupply;
    }

    function totalSupply() public view returns (uint256) {
        return _currentId;
    }

    /**
     * @notice Mint a rarity society.
     */
    function mint(uint256 amount) public returns (uint256) {
        require(totalSupply() < maxSupply, "max supply reached");
        return mintToken(_currentId++, amount);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return "";
    }

    function mintToken(uint256 tokenId, uint256 amount) public returns (uint256) {
        _mint(owner(), minter, tokenId, amount, "");
        return tokenId;
    }

    function mintTokenTo(uint256 tokenId, address to, uint256 amount) public returns (uint256) {
        _mint(owner(), to, tokenId, amount, "");
        return tokenId;
    }

    function burn(uint256 tokenId, uint256 amount) public {
        _burn(minter, tokenId, amount);
    }

}

