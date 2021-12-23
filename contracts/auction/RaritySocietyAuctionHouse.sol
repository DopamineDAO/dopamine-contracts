// LICENSE
// NounsAuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by Nounders DAO.

pragma solidity ^0.8.9;

import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IRaritySocietyAuctionHouse } from '../interfaces/IRaritySocietyAuctionHouse.sol';
import { IRarityPass } from '../interfaces/IRarityPass.sol';
import { IWETH } from '../interfaces/IWETH.sol';

contract RaritySocietyAuctionHouse is IRaritySocietyAuctionHouse, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {

    uint256 public constant MIN_TIME_BUFFER = 60 seconds;
    uint256 public constant MAX_TIME_BUFFER = 24 hours;

    uint256 public constant MIN_RESERVE_PRICE = 1 wei;
    uint256 public constant MAX_RESERVE_PRICE = 99 ether;

    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 1 weeks;

    uint256 public constant MAX_TREASURY_SPLIT = 100;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public constant MIN_BID_INCREMENT_PERCENTAGE = 5;

    // The Nouns ERC721 token contract
    IRarityPass public token;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The percentage of auction proceeds to direct to the treasury
    uint256 public treasurySplit;

    // The duration of a single auction (seconds)
    uint256 public duration;

    // The active auction
    Auction public auction;

    // Team multisig address
    address public reserve;

    /**
     * @notice Initialize the auction house and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     */
    function initialize(
        IRarityPass _token,
        address _reserve,
        address _weth,
        uint256 _treasurySplit,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _duration
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();

        _pause();

        require(
            _timeBuffer >= MIN_TIME_BUFFER && _timeBuffer <= MAX_TIME_BUFFER,
            'time buffer is invalid'
        );
        require(
            _reservePrice >= MIN_RESERVE_PRICE && _reservePrice <= MAX_RESERVE_PRICE,
            'reserve price is invalid'
        );
        require(
            _treasurySplit <= MAX_TREASURY_SPLIT,
            'treasury split is invalid'
        );
        require(
            _duration >= MIN_DURATION && _duration <= MAX_DURATION,
            'duration is invalid'
        );

        emit AuctionTreasurySplitSet(_treasurySplit);
        emit AuctionTimeBufferSet(_timeBuffer);
        emit AuctionReservePriceSet(_reservePrice);
        emit AuctionDurationSet(_duration);

        token = _token;
        weth = _weth;
        reserve = _reserve;

        treasurySplit = _treasurySplit;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        duration = _duration;
    }

    /**
     * @notice Settle the current auction, mint a new Noun, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a Noun, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 tokenId) external payable override nonReentrant {
        Auction memory _auction = auction;

        require(_auction.tokenId == tokenId, 'Rarity Pass not up for auction');
        require(block.timestamp < _auction.endTime, 'Auction expired');
        require(msg.value >= reservePrice, 'Bid lower than reserve price');
        require(
            msg.value >= _auction.amount + ((_auction.amount * MIN_BID_INCREMENT_PERCENTAGE) / 100),
            'Bid must be at least 5% greater than last bid'
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
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

    /**
     * @notice Pause the Nouns auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the Nouns auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }
        
    /**
     * @notice Set the auction duration.
     * @dev Only callable by the owner.
     */
    function setDuration(uint256 _duration) external override onlyOwner {
        require(
            _duration >= MIN_DURATION && _duration <= MAX_DURATION,
            'duration is invalid'
        );

        duration = _duration;

        emit AuctionDurationSet(_duration);
    }

    /**
     * @notice Set the auction team fee percentage.
     * @dev Only callable by the owner.
     */
    function setTreasurySplit(uint256 _treasurySplit) external override onlyOwner {
        require(
            _treasurySplit <= MAX_TREASURY_SPLIT,
            'treasury split is invalid'
        );

        treasurySplit = _treasurySplit;

        emit AuctionTreasurySplitSet(_treasurySplit);
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        require(
            _timeBuffer >= MIN_TIME_BUFFER && _timeBuffer <= MAX_TIME_BUFFER,
            'time buffer is invalid'
        );
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferSet(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice) external override onlyOwner {
        require(
            _reservePrice >= MIN_RESERVE_PRICE && _reservePrice <= MAX_RESERVE_PRICE,
            'reserve price is invalid'
        );
        reservePrice = _reservePrice;

        emit AuctionReservePriceSet(_reservePrice);
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
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
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the Noun is burned.
     */
    function _settleAuction() internal {
        Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, 'Auction has already been settled');
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            token.transferFrom(address(this), owner(), _auction.tokenId);
        } else {
            token.transferFrom(address(this), _auction.bidder, _auction.tokenId);
        }

        if (_auction.amount > 0) {
            uint256 treasuryProceeds = _auction.amount * treasurySplit / 100;
            uint256 teamProceeds = _auction.amount - treasuryProceeds;
            _safeTransferETHWithFallback(owner(), treasuryProceeds);
            _safeTransferETHWithFallback(reserve, teamProceeds);
        }

        emit AuctionSettled(_auction.tokenId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}
