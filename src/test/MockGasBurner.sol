// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import { IRaritySocietyAuctionHouse } from '../interfaces/IRaritySocietyAuctionHouse.sol';

contract MaliciousBidder {
    function bid(IRaritySocietyAuctionHouse auctionHouse, uint256 tokenId) public payable {
        auctionHouse.createBid{ value: msg.value }(tokenId);
    }

    receive() external payable {
        while (gasleft() > 30_000) {}
    }
}
