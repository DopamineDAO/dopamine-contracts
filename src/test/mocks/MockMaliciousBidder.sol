// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import { IDopamineAuctionHouse } from '../../interfaces/IDopamineAuctionHouse.sol';

error MaliciousRevert();

contract MockMaliciousBidder {
    function createBid(IDopamineAuctionHouse auctionHouse, uint256 tokenId) public payable {
        auctionHouse.createBid{ value: msg.value }(tokenId);
    }

    receive() external payable {
        revert MaliciousRevert();
    }
}
