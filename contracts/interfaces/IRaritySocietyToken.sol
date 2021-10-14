// SPDX-License-Identifier: GPL-3.0

/// @title Interface for RaritySocietyToken

pragma solidity ^0.8.9;

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IRaritySocietyToken is IERC721 {
    event Mint(uint256 indexed tokenId);

    event Burn(uint256 indexed tokenId);

    event ChangeMinter(address minter);

    event LockMinter();

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMinter(address minter) external;

    function lockMinter() external;
}
