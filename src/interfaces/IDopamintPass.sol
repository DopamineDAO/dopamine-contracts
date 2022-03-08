// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./IDopamintPassEvents.sol";

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IDopamintPass is IERC721, IDopamintPassEvents {

    struct Drop {

        uint256 endIndex;

        bool initiated;

        uint256 endTime;
    }

    function setDropDelay(uint256 dropDelay) external;

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMinter(address minter) external;

    function lockMinter() external;
}
