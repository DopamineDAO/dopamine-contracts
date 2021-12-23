// SPDX-License-Identifier: GPL-3.0

/// @title Interface for RaritySocietyToken

pragma solidity ^0.8.9;

import { IERC721Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

interface IRarityPass is IERC721Upgradeable {

    struct Drop {

        uint256 endIndex;

        bool initiated;

        uint256 endTime;
    }

    event Mint(uint256 indexed tokenId);

    event Burn(uint256 indexed tokenId);

    event ChangeMinter(address minter);

    event LockMinter();

    event NewDropDelay(uint256 dropDelay);

    event DropCreated(uint256 indexed dropId, uint256 startIndex, uint256 dropSize, uint256 startTime, string dropHash);

    event DropCompleted(uint256 indexed dropId, uint256 endTime);

    event DropDelegate(address delegator, address delegatee, uint256 tokenId);

    function setDropDelay(uint256 dropDelay) external;

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMinter(address minter) external;

    function lockMinter() external;
}
