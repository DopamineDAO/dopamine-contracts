// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import { IRaritySocietyAuctionHouse } from '../interfaces/IRaritySocietyAuctionHouse.sol';

contract GasBurner {
    function createBid(IRaritySocietyAuctionHouse auctionHouse, uint256 tokenId) public payable {
        auctionHouse.createBid{ value: msg.value }(tokenId);
    }

    receive() external payable {
        uint256 x = 0;
        while (gasleft() > 0) {
            x++;
        }
    }
}
