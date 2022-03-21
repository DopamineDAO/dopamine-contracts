// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./IDopamineAuctionHouseEvents.sol";

interface IDopamineAuctionHouse is IDopamineAuctionHouseEvents {

    struct Auction {
        uint256 tokenId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        address payable bidder;
        bool settled;
    }

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function pause() external;

    function unpause() external;

    function createBid(uint256 tokenId) external payable;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setTreasurySplit(uint256 teamFeePercentage) external;

    function setPendingAdmin(address newPendingAdmin) external;

    function acceptAdmin() external;

    function setDuration(uint256 duration) external;

}
