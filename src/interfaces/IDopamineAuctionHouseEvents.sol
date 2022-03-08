interface IDopamineAuctionHouseEvents {

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

    event AuctionPaused(address pauser);

    event AuctionUnpaused(address unpauser);
    
    event AuctionSettled(
        uint256 indexed tokenId,
        address winner,
        uint256 amount
    );

    event AuctionTimeBufferSet(uint256 timeBuffer);

    event AuctionReservePriceSet(uint256 reservePrice);

    event AuctionTreasurySplitSet(uint256 teamFeePercentage);

    event AuctionDurationSet(uint256 duration);

    event NewPendingAdmin(address pendingAdmin);

    event NewAdmin(address oldAdmin, address newAdmin);

    event RefundFailed(address refunded);

}

