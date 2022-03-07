// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './DopamineAuctionHouseStorage.sol';
import { IDopamineAuctionHouse } from '../interfaces/IDopamineAuctionHouse.sol';
import { IDopamineAuctionHouseToken } from '../interfaces/IDopamineAuctionHouseToken.sol';
import { IWETH } from '../interfaces/IWETH.sol';

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

contract DopamineAuctionHouse is UUPSUpgradeable, DopamineAuctionHouseStorageV1, IDopamineAuctionHouse {

    // The minimum percentage difference between the last bid amount and the current bid.
    uint256 public constant MIN_BID_DIFF = 5;

    uint256 public constant MIN_TIME_BUFFER = 60 seconds;
    uint256 public constant MAX_TIME_BUFFER = 24 hours;

    uint256 public constant MIN_RESERVE_PRICE = 1 wei;
    uint256 public constant MAX_RESERVE_PRICE = 99 ether;

    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 1 weeks;

    uint256 private constant _UNLOCKED = 1;
    uint256 private constant _LOCKED = 2;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    modifier whenNotPaused() {
        if (_paused != _UNLOCKED) {
            revert PausedAuction();
        }
        _;
    }

    modifier whenPaused() {
        if (_paused != _LOCKED) {
            revert UnpausedAuction();
        }
        _;
    }

    modifier nonReentrant() {
        if (_locked != _UNLOCKED) {
            revert Reentrant();
        }
        _locked = _LOCKED;
        _;
        _locked = _UNLOCKED;
    }

    /// @notice Initialize the Auctions contract.
    /// @param token_ NFT factory address, from which auctioned NFTs are minted.
    /// @param reserve_ Address of the Dopamine company treasury.
    /// @param dao_ Address of the Dopamine DAO treasury.
    /// @param treasurySplit_ Revenue split % between `dao_` and `reserve_`.
    /// @param timeBuffer_ Timeframe in epoch seconds auctions may be extended.
    /// @param reservePrice_ Minimal bidding price for auctions.
    /// @param duration_ How long in seconds an auction should stay open.
    function initialize(
        address token_,
        address payable reserve_,
        address payable dao_,
        uint256 treasurySplit_,
        uint256 timeBuffer_,
        uint256 reservePrice_,
        uint256 duration_
    ) onlyProxy external {
        if (address(token) != address(0)) {
            revert AlreadyInitialized();
        }

        _paused = _UNLOCKED;
        _locked = _UNLOCKED;

        _pause();

        admin = msg.sender;
        token = IDopamineAuctionHouseToken(token_);
        dao = dao_;
        reserve = reserve_;

        setTreasurySplit(treasurySplit_);
        setTimeBuffer(timeBuffer_);
        setReservePrice(reservePrice_);
        setDuration(duration_);
    }

    /// @notice Settle the ongoing auction and create a new one.
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @notice Settle the ongoing auction.
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /// @notice Place a bid for the current NFT being auctioned.
    /// @param tokenId The identifier of the NFT currently being auctioned.
    function createBid(uint256 tokenId) external payable override nonReentrant {
        Auction memory _auction = auction;

        if (block.timestamp > _auction.endTime) {
            revert ExpiredAuction();
        }
        if (_auction.tokenId != tokenId) {
            revert NotUpForAuction();
        }
        if (
            msg.value < reservePrice || 
            msg.value < _auction.amount + ((_auction.amount * MIN_BID_DIFF) / 100)
        ) {
            revert BidTooLow();
        }

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0) && !_transferETH(lastBidder, _auction.amount)) {
            emit RefundFailed(lastBidder);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp <= timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
            emit AuctionExtended(_auction.tokenId, _auction.endTime);
        }

        emit AuctionBid(_auction.tokenId, msg.sender, msg.value, extended);
    }

    /// @notice Pause the current auction.
    function pause() external override onlyAdmin {
        _pause();
    }

    /// @notice Resumes an existing auction or creates a new auction.
    function unpause() external override onlyAdmin {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }
        
    /// @notice Sets a new pending admin `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
    function setPendingAdmin(address newPendingAdmin) public override onlyAdmin {
        pendingAdmin = newPendingAdmin;
        emit NewPendingAdmin(pendingAdmin);
    }

    /// @notice Convert the current `pendingAdmin` to the new `admin`.
	function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

		emit NewAdmin(admin, pendingAdmin);
		admin = pendingAdmin;
        pendingAdmin = address(0);
	}

    /// @notice Sets a new auctions bidding duration, `newDuration`.
    /// @dev `duration` refers to how long an individual auction remains open.
    /// @param newDuration New auction duration to set, in seconds.
    function setDuration(uint256 newDuration) public override onlyAdmin {
        if (newDuration < MIN_DURATION || newDuration > MAX_DURATION) {
            revert InvalidDuration();
        }
        duration = newDuration;
        emit AuctionDurationSet(duration);
    }

    /// @notice Sets a new treasury split, `newTreasurySplit`.
    /// @dev `treasurySplit` refers to % of sale revenue directed to treasury.
    /// @param newTreasurySplit The new treasury split to set, in percentage.
    function setTreasurySplit(uint256 newTreasurySplit) public override onlyAdmin {
        if (newTreasurySplit > 100) {
            revert InvalidTreasurySplit();
        }
        treasurySplit = newTreasurySplit;
        emit AuctionTreasurySplitSet(treasurySplit);
    }

    /// @notice Sets a new auction time buffer, `newTimeBuffer`.
    /// @dev Auctions extend if bid received within `timeBuffer` of auction end.
    /// @param newTimeBuffer The time buffer to set, in seconds since epoch.
    function setTimeBuffer(uint256 newTimeBuffer) public override onlyAdmin {
        if (newTimeBuffer < MIN_TIME_BUFFER || newTimeBuffer > MAX_TIME_BUFFER) {
            revert InvalidTimeBuffer();
        }
        timeBuffer = newTimeBuffer;
        emit AuctionTimeBufferSet(timeBuffer);
    }

    /// @notice Sets a new auction reserve price, `newReservePrice`.
    /// @dev `reservePrice` represents the English auction starting price.
    /// @param newReservePrice The new reserve price to set, in wei.
    function setReservePrice(uint256 newReservePrice) public override onlyAdmin {
        if (newReservePrice < MIN_RESERVE_PRICE || newReservePrice > MAX_RESERVE_PRICE) {
            revert InvalidReservePrice();
        }
        reservePrice = newReservePrice;
        emit AuctionReservePriceSet(reservePrice);
    }

    function paused() public view returns (bool) {
        return _paused == _LOCKED;
    }

    /// @notice Puts the NFT produced by `token.mint()` up for auction.
    /// @dev If minting fails, the auction contract is paused.
    function _createAuction() internal {
        try token.mint() returns (uint256 tokenId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({
                tokenId: tokenId,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            emit AuctionCreated(tokenId, startTime, endTime);
        } catch {
            _pause();
        }
    }

    /// @notice Settles the auction, transferring NFT to winning bidder.
    /// @dev If no bids are placed, the NFT is sent to the treasury.
    function _settleAuction() internal {
        Auction memory _auction = auction;

        if (_auction.startTime == 0) {
            revert UncommencedAuction();
        }
        if (_auction.settled) {
            revert AlreadySettled();
        }
        if (block.timestamp < _auction.endTime) {
            revert IncompleteAuction();
        }

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            token.transferFrom(address(this), dao, _auction.tokenId);
        } else {
            token.transferFrom(address(this), _auction.bidder, _auction.tokenId);
        }

        if (_auction.amount > 0) {
            uint256 treasuryProceeds = _auction.amount * treasurySplit / 100;
            uint256 teamProceeds = _auction.amount - treasuryProceeds;
            _transferETH(dao, treasuryProceeds);
            _transferETH(reserve, teamProceeds);
        }

        emit AuctionSettled(_auction.tokenId, _auction.bidder, _auction.amount);
    }

    /// @notice Transfer `value` worth of Eth to address `to`.
    /// @dev Only up to 30K worth of gas will be forwarded to callee.
    /// @return `true` if refund is successful, `false` otherwise.
    function _transferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }

    /// @notice Pauses the auctions contract if not paused.
    function _pause() internal whenNotPaused {
        _paused = _LOCKED;
        emit AuctionPaused(msg.sender);
    }

    /// @notice Unpauses the auctions contract if paused.
    function _unpause() internal whenPaused {
        _paused = _UNLOCKED;
        emit AuctionUnpaused(msg.sender);
    }

    /// @notice Performs authorization check for UUPS upgrades.
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != admin) {
            revert UnauthorizedUpgrade();
        }
    }
}
