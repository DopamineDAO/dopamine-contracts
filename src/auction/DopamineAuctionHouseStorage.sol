// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import '../interfaces/IDopamineAuctionHouse.sol';
import { IDopamineAuctionHouseToken } from '../interfaces/IDopamineAuctionHouseToken.sol';

contract DopamineAuctionHouseStorageV1 {

    // The DopamintPass ERC721 token contract.
    IDopamineAuctionHouseToken public token;

    // The address of the pending admin of the auction house contract.
    address public pendingAdmin;

    // The address of the admin of the auction house contract.
    address public admin;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The percentage of auction proceeds to direct to the treasury
    uint256 public treasurySplit;

    // The duration of a single auction (seconds)
    uint256 public duration;

    // The active auction
    IDopamineAuctionHouse.Auction public auction;

    // DAO treasury address.
    address payable public dao;

    // Team multisig address
    address payable public reserve;

    // Marker preventing reentrancy.
    uint256 internal _locked;

    // Indicates whether or not auction is paused.
    uint256 internal _paused;
}


