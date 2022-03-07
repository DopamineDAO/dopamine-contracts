// SPDX-License-Identifier: GPL-3.0

/// @title Interface for DopamineAuctionHouse

pragma solidity ^0.8.9;

interface IDopamineAuctionHouse {

    /// @notice Function callable only by the admin.
    error AdminOnly();

    /// @notice Auctions contract already initialized.
    error AlreadyInitialized();

    /// @notice Auction has already been settled.
    error AlreadySettled();

    /// @notice Bid placed was too low (see `reservePrice` and `MIN_BID_DIFF`).
    error BidTooLow();

    /// @notice The auction has expired.
    error ExpiredAuction();

    /// @notice Auction has yet to complete.
    error IncompleteAuction();

    /// @notice Auction duration set is invalid.
    error InvalidDuration();

    /// @notice Reserve price set is invalid.
    error InvalidReservePrice();

    /// @notice Time buffer set is invalid.
    error InvalidTimeBuffer();

    /// @notice Treasury split is invalid, must be in range [0, 100].
    error InvalidTreasurySplit();

    /// @notice The NFT specified is not up for auction.
    error NotUpForAuction();

    /// @notice Function callable only by the pending owner.
    error PendingAdminOnly();

    /// @notice Reentrancy vulnerability.
    error Reentrant();

    /// @notice Operation cannot be performed as auction is paused.
    error PausedAuction();

    /// @notice Upgrade requires either admin or vetoer privileges.
    error UnauthorizedUpgrade();

    /// @notice Auction has not yet started.
    error UncommencedAuction();

    /// @notice Operation cannot be performed as auction is unpaused.
    error UnpausedAuction();


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
