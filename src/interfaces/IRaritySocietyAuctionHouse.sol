// SPDX-License-Identifier: GPL-3.0

/// @title Interface for RaritySocietyAuctionHouse

pragma solidity ^0.8.9;

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IRaritySocietyAuctionHouse {

    struct Auction {
        uint256 tokenId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        address payable bidder;
        bool settled;
    }

    event AuctionCreated(
        uint256 indexed tokenId,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(
        uint256 indexed tokenId,
        address bidder,
        uint256 value,
        bool extended
    );

    event AuctionExtended(
        uint256 indexed tokenId,
        uint256 endTime
    );

    event AuctionSettled(
        uint256 indexed tokenId,
        address winner,
        uint256 amount
    );

    event AuctionTimeBufferSet(uint256 timeBuffer);

    event AuctionReservePriceSet(uint256 reservePrice);

    event AuctionTreasurySplitSet(uint256 teamFeePercentage);

    event AuctionDurationSet(uint256 duration);

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function pause() external;

    function unpause() external;

    function createBid(uint256 tokenId) external payable;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setTreasurySplit(uint256 teamFeePercentage) external;

    function setDuration(uint256 duration) external;

}
