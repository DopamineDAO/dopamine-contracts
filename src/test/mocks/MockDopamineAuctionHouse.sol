// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import { DopamineAuctionHouse } from '../../auction/DopamineAuctionHouse.sol';
import { IDopamineAuctionHouseToken } from '../../interfaces/IDopamineAuctionHouseToken.sol';

/// @title Mock contract for Dopamine Auction House
contract MockDopamineAuctionHouse is DopamineAuctionHouse {

    // Retrieve auction as struct for easier testing.
    function getAuction() public returns (Auction memory) {
        return auction;
    }

}
