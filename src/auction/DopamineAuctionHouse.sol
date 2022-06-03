// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// This file is under the copyright license: Copyright 2021 Zora Labs, Inc.
/// 
/// DoapmineAuctionHouse is a modification of Nouns DAO's NounsAuctionHouse.sol:
/// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/NounsAuctionHouse.sol
///
/// Copyright licensing is under the GPL-3.0 license, as the above contract
/// is itself a modification of Zora's Auction House (GPL-3.0 licensed).
/// 
/// The following major changes were made from the original Nouns DAO contract:
/// - `SettleCurrentAndCreateNewAuction()` and `SettleAuction()` were unified
///   into a single `SettleAuction()` function that can be called paused or not
/// - Auctions begin with `auction.settled = true` to make settlements simpler
/// - The semantics around pausing vs. unpausing were changed to orient around
///   suspension of NEW auctions (pausing had no effect on the current auction)
/// - Adds `AuctionCreationFailed` event emitted during failed auction creation
/// - Proxy was changed from OZ's TransparentUpgradeableProxy to OZ's UUPS proxy
/// - Support for WETH as a fallback for failed ETH refunds was removed
/// - Support for splitting auction revenue with another address was added
/// - Failed ETH refunds now emit `RefundFailed` events

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import '../errors.sol';
import { DopamineAuctionHouseStorage } from "./DopamineAuctionHouseStorage.sol";
import { IDopamineAuctionHouse } from "../interfaces/IDopamineAuctionHouse.sol";
import { IDopamineAuctionHouseToken } from "../interfaces/IDopamineAuctionHouseToken.sol";

/// @title Dopamine Auction House Contract
/// @notice The DopamineAuctionHouse contract is an English auctions platform
///  that allows any integrated NFT to be auctioned one-at-a-time providing the
///  NFT conforms to the IDopamineAuctionHouseToken interface. In Dopamine DAO
///  the tokens are meant to be the Dopamine passes, with the auction house
///  controlling its overall emissions schedule. 
//// @dev It is intended for the admin to be the team multi-sig address.
contract DopamineAuctionHouse is UUPSUpgradeable, DopamineAuctionHouseStorage, IDopamineAuctionHouse {

    /// @notice The min % difference a bidder must bid relative to the last bid.
    uint256 public constant MIN_BID_DIFF = 5;

    /// @notice The minimum time buffer in seconds that can be set for auctions.
    uint256 public constant MIN_TIME_BUFFER = 60 seconds;

    /// @notice The maximum time buffer in seconds that can be set for auctions.
    uint256 public constant MAX_TIME_BUFFER = 24 hours;

    /// @notice The minimum reserve price in wei that can be set for auctions.
    uint256 public constant MIN_RESERVE_PRICE = 1 wei;

    /// @notice The maximum reserve price in wei that can be set for auctions.
    uint256 public constant MAX_RESERVE_PRICE = 99 ether;

    /// @notice The minimum time period an auction can run for in seconds.
    uint256 public constant MIN_AUCTION_DURATION = 10 minutes;

    /// @notice The maximum time period an auction can run for in seconds.
    uint256 public constant MAX_AUCTION_DURATION = 1 weeks;

    /// @dev Gas efficient reentrancy & suspension marker representing True.
    uint256 private constant _TRUE = 1;

    /// @dev Gas efficient reentrancy & suspension marker representing False.
    uint256 private constant _FALSE = 2;

    /// @notice This modifier restrict calls to only the admin.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    /// @notice This modifier acts as a reentrancy guard.
    modifier nonReentrant() {
        if (_locked != _FALSE) {
            revert FunctionReentrant();
        }
        _locked = _TRUE;
        _;
        _locked = _FALSE;
    }

    /// @notice Initialize the Auctions contract.
    /// @param token_           The address of the NFT up for auction.
    /// @param reserve_         Address of the Dopamine team reserve.
    /// @param dao_             Address of the Dopamine DAO treasury.
    /// @param treasurySplit_   Revenue split % between `dao_` and `reserve_`.
    /// @param timeBuffer_      Time window in seconds auctions may be extended.
    /// @param reservePrice_    The minimum biddinng price for auctions in wei.
    /// @param auctionDuration_ How long in seconds an auction is up for.
    function initialize(
        address token_,
        address payable reserve_,
        address payable dao_,
        uint256 treasurySplit_,
        uint256 timeBuffer_,
        uint256 reservePrice_,
        uint256 auctionDuration_
    ) onlyProxy external {
        if (address(token) != address(0)) {
            revert ContractAlreadyInitialized();
        }

        _suspended = _TRUE;
        _locked = _FALSE;

        admin = msg.sender;
		emit AdminChanged(address(0), admin);

        token = IDopamineAuctionHouseToken(token_);
        dao = dao_;
        reserve = reserve_;

        auction.settled = true;

        setTreasurySplit(treasurySplit_);
        setTimeBuffer(timeBuffer_);
        setReservePrice(reservePrice_);
        setAuctionDuration(auctionDuration_);
    }

    /// @inheritdoc IDopamineAuctionHouse
    function suspended() external view returns (bool) {
        return _suspended == _TRUE;
    }

    /// @inheritdoc IDopamineAuctionHouse
    function suspendNewAuctions() external onlyAdmin {
        if (_suspended == _TRUE) {
            revert AuctionAlreadySuspended();
        }
        _suspended = _TRUE;
        emit AuctionSuspended();
    }

    /// @inheritdoc IDopamineAuctionHouse
    function resumeNewAuctions() external onlyAdmin {

        // This function can only be called if auctions are currently suspended.
        if (_suspended == _FALSE) {
            revert AuctionNotSuspended();
        }

        // Unless auction settles and ensuing creation fails, resume auction.
        if (!auction.settled || _createAuction()) {
            _suspended = _FALSE;
            emit AuctionResumed();
        }
    }
        
    /// @inheritdoc IDopamineAuctionHouse
    function settleAuction() external nonReentrant {
        _settleAuction();

        // If new auctions are live, create new auction but suspend if it fails.
        if (_suspended != _TRUE && !_createAuction()) {
            _suspended = _TRUE;
            emit AuctionSuspended();
        }
    }

    /// @inheritdoc IDopamineAuctionHouse
    function createBid(uint256 tokenId) external payable nonReentrant {
        if (block.timestamp > auction.endTime) {
            revert AuctionExpired();
        }
        if (auction.tokenId != tokenId) {
            revert AuctionBidInvalid();
        }
        if (
            msg.value < reservePrice || 
            msg.value < auction.amount + ((auction.amount * MIN_BID_DIFF) / 100)
        ) {
            revert AuctionBidTooLow();
        }

        address payable lastBidder = auction.bidder;

        // Emit a `RefundFailed` event if the refund to the last bidder fails.
        // This only happens if the bidder is a contract not accepting payments.
        if (
            lastBidder != address(0) && 
            !_transferETH(lastBidder, auction.amount)
        ) 
        {
            emit RefundFailed(lastBidder);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if bid received within `timeBuffer` of end time.
        bool extended = auction.endTime - block.timestamp < timeBuffer;
        emit AuctionBid(auction.tokenId, msg.sender, msg.value, extended);

        if (extended) {
            auction.endTime = block.timestamp + timeBuffer;
            emit AuctionExtended(tokenId, auction.endTime);
        }

    }

    /// @inheritdoc IDopamineAuctionHouse
    function setPendingAdmin(address newPendingAdmin) public override onlyAdmin {
        pendingAdmin = newPendingAdmin;
        emit PendingAdminSet(pendingAdmin);
    }

    /// @inheritdoc IDopamineAuctionHouse
	function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

		emit AdminChanged(admin, pendingAdmin);
		admin = pendingAdmin;
        pendingAdmin = address(0);
	}

    /// @inheritdoc IDopamineAuctionHouse
    function setAuctionDuration(uint256 newAuctionDuration) public onlyAdmin {
        if (
            newAuctionDuration < MIN_AUCTION_DURATION || 
            newAuctionDuration > MAX_AUCTION_DURATION
        ) {
            revert AuctionDurationInvalid();
        }
        auctionDuration = newAuctionDuration;
        emit AuctionDurationSet(auctionDuration);
    }

    /// @inheritdoc IDopamineAuctionHouse
    function setTreasurySplit(uint256 newTreasurySplit) public override onlyAdmin {
        if (newTreasurySplit > 100) {
            revert AuctionTreasurySplitInvalid();
        }
        treasurySplit = newTreasurySplit;
        emit AuctionTreasurySplitSet(treasurySplit);
    }

    /// @inheritdoc IDopamineAuctionHouse
    function setTimeBuffer(uint256 newTimeBuffer) public override onlyAdmin {
        if (newTimeBuffer < MIN_TIME_BUFFER || newTimeBuffer > MAX_TIME_BUFFER) {
            revert AuctionTimeBufferInvalid();
        }
        timeBuffer = newTimeBuffer;
        emit AuctionTimeBufferSet(timeBuffer);
    }

    /// @inheritdoc IDopamineAuctionHouse
    function setReservePrice(uint256 newReservePrice) public override onlyAdmin {
        if (
            newReservePrice < MIN_RESERVE_PRICE ||
            newReservePrice > MAX_RESERVE_PRICE
        ) {
            revert AuctionReservePriceInvalid();
        }
        reservePrice = newReservePrice;
        emit AuctionReservePriceSet(reservePrice);
    }

    /// @notice Puts the NFT produced by `token.mint()` up for auction.
    /// @return created True if auction creation succeeds, false otherwise.
    function _createAuction() internal returns (bool created) {
        try token.mint() returns (uint256 tokenId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + auctionDuration;

            auction = Auction({
                tokenId: tokenId,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            created = true;
            emit AuctionCreated(tokenId, startTime, endTime);
        } catch {
            emit AuctionCreationFailed();
        }
    }

    /// @notice Settles the auction, transferring the NFT to the winning bidder.
    /// @dev If no bids are placed, the NFT is sent to the treasury.
    function _settleAuction() internal {
        if (auction.settled) {
            revert AuctionAlreadySettled();
        }
        if (block.timestamp < auction.endTime) {
            revert AuctionOngoing();
        }

        auction.settled = true;

        if (auction.bidder == address(0)) {
            token.transferFrom(address(this), dao, auction.tokenId);
        } else {
            token.transferFrom(address(this), auction.bidder, auction.tokenId);
        }

        if (auction.amount > 0) {
            uint256 treasuryProceeds = auction.amount * treasurySplit / 100;
            uint256 teamProceeds = auction.amount - treasuryProceeds;
            _transferETH(dao, treasuryProceeds);
            _transferETH(reserve, teamProceeds);
        }

        emit AuctionSettled(auction.tokenId, auction.bidder, auction.amount);
    }

    /// @notice Transfer `value` worth of Eth to address `to`.
    /// @dev Only up to 30K worth of gas will be forwarded to callee.
    /// @return `true` if refund is successful, `false` otherwise.
    function _transferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }

    /// @notice Performs an authorization check for UUPS upgrades.
    /// @dev This function ensures only the admin can upgrade the DAO.
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != admin) {
            revert UpgradeUnauthorized();
        }
    }

}
