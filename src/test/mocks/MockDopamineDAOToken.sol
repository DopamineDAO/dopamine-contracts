// SPDX-License-Identifier: GPL-3.0

/// @title The Dopamine DAO ERC-721 token

pragma solidity ^0.8.9;

import { ERC721Checkpointable } from '../../erc721/ERC721Checkpointable.sol';
import { ERC721 } from '../../erc721/ERC721.sol';

contract MockDopamineDAOToken is ERC721Checkpointable {

    address public minter;

    string private constant NAME = 'Dopamine';
    string private constant SYMBOL = 'DOPE';

    constructor(address minter_, uint256 maxSupply_) ERC721Checkpointable(NAME, SYMBOL, maxSupply_) {
        minter = minter_;
    }

    function mint() public returns (uint256) {
        return mintToken(totalSupply);
    }

    function batchMint(uint256 numTokens) public {
        for (uint256 i = 0; i < numTokens; i++) {
            mintToken(totalSupply);
        }
    }

    function mintToken(uint256 tokenId) public returns (uint256) {
        _mint(minter, tokenId);
        return tokenId;
    }

}

