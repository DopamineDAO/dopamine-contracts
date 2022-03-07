// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./mocks/MockDopamineAuctionHouse.sol";
import "./mocks/MockDopamineAuctionHouseToken.sol";
import "../auction/DopamineAuctionHouse.sol";

import "./utils/test.sol";
import "./utils/console.sol";

contract MockContractUnpayable { }
contract MockContractPayable { receive() external payable {} }

/// @title Dopamine Auction Test Suites
contract DopamineAuctionHouseTest is Test {

    bool constant PROXY = true;

    uint256 constant NFT = 0;
    uint256 constant NFT_1 = 1;

    /// @notice Default auction house parameters.
    uint256 constant TREASURY_SPLIT = 50; // 50%
    uint256 constant TIME_BUFFER = 10 minutes;
    uint256 constant RESERVE_PRICE = 1 ether;
    uint256 constant DURATION = 60 * 60 * 12; // 12 hours

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    /// @notice Addresses used for testing.
    address constant ADMIN = address(1337);
    address constant BIDDER = address(99);
    address constant BIDDER_1 = address(99);
    address constant DAO = address(69);
    address constant RESERVE = address(1);

    MockDopamineAuctionHouseToken token;
    MockDopamineAuctionHouse ah;
    MockDopamineAuctionHouse ahImpl;

    uint256 constant BIDDER_INITIAL_BAL = 8888 ether;
    uint256 constant BIDDER_1_INITIAL_BAL = 10 ether;

    address payable reserve;
    address payable dao;

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

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(ADMIN);

        vm.deal(address(BIDDER), BIDDER_INITIAL_BAL);
        vm.deal(address(BIDDER_1), BIDDER_1_INITIAL_BAL);

        reserve = payable(address(new MockContractPayable()));
        dao = payable(address(new MockContractPayable()));
        ahImpl = new MockDopamineAuctionHouse();
        address proxyAddr = getContractAddress(address(ADMIN), 0x04); 

        token = new MockDopamineAuctionHouseToken(proxyAddr, 99);
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            DURATION
        );
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);
        ah = MockDopamineAuctionHouse(address(proxy));
    }

    function testInitialize() public {
        /// Correctly sets all auction house parameters.
        assertEq(address(ah.token()), address(token));
        assertEq(ah.pendingAdmin(), address(0));
        assertEq(ah.admin(), ADMIN);
        assertEq(ah.timeBuffer(), TIME_BUFFER);
        assertEq(ah.reservePrice(), RESERVE_PRICE);
        assertEq(ah.treasurySplit(), TREASURY_SPLIT);
        assertEq(ah.duration(), DURATION);
        assertEq(ah.dao(), dao);
        assertEq(ah.reserve(), reserve);
        assertTrue(ah.paused());

        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, 0);
        assertEq(auction.amount, 0);
        assertEq(auction.startTime, 0);
        assertEq(auction.endTime, 0);
        assertEq(auction.bidder, address(0));
        assertTrue(!auction.settled);

        /// Reverts when trying to initialize more than once.
        expectRevert("AlreadyInitialized()");
        ah.initialize(
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            DURATION
        );

        /// Reverts when setting invalid treasury split.
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            dao,
            101,
            TIME_BUFFER,
            RESERVE_PRICE,
            DURATION
        );
        expectRevert("InvalidTreasurySplit()");
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid time buffer.
        uint256 invalidParam = ah.MIN_TIME_BUFFER() - 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            invalidParam,
            RESERVE_PRICE,
            DURATION
        );
        expectRevert("InvalidTimeBuffer()");
		proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid reserve price.
        invalidParam = ah.MAX_RESERVE_PRICE() + 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            TIME_BUFFER,
            invalidParam,
            DURATION
        );
        expectRevert("InvalidReservePrice()");
		proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid duration.
        invalidParam = ah.MIN_DURATION() - 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            invalidParam
        );
        expectRevert("InvalidDuration()");
		proxy = new ERC1967Proxy(address(ahImpl), data);
    }

    function testSetTreasurySplit() public {
        // Reverts when the treasury split is too high.
        expectRevert("InvalidTreasurySplit()");
        ah.setTreasurySplit(101);

        // Emits expected `AuctionTreasurySplitSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTreasurySplitSet(TREASURY_SPLIT);
        ah.setTreasurySplit(TREASURY_SPLIT);
    }

    function testSetTimeBuffer() public {
        // Reverts when time buffer too small.
        uint256 minTimeBuffer = ah.MIN_TIME_BUFFER();
        expectRevert("InvalidTimeBuffer()");
        ah.setTimeBuffer(minTimeBuffer - 1);

        // Reverts when time buffer too large.
        uint256 maxTimeBuffer = ah.MAX_TIME_BUFFER();
        expectRevert("InvalidTimeBuffer()");
        ah.setTimeBuffer(maxTimeBuffer + 1);

        // Emits expected `AuctionTimeBufferSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTimeBufferSet(TIME_BUFFER);
        ah.setTimeBuffer(TIME_BUFFER);
    }

    function testSetReservePrice() public {
        // Reverts when reserve price is too low.
        uint256 minReservePrice = ah.MIN_RESERVE_PRICE();
        expectRevert("InvalidReservePrice()");
        ah.setReservePrice(minReservePrice - 1);

        // Reverts when reserve price is too high.
        uint256 maxReservePrice = ah.MAX_RESERVE_PRICE();
        expectRevert("InvalidReservePrice()");
        ah.setReservePrice(maxReservePrice + 1);

        // Emits expected `AuctionReservePriceSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionReservePriceSet(RESERVE_PRICE);
        ah.setReservePrice(RESERVE_PRICE);
    }

    function testSetDuration() public {
        // Reverts when duration is too low.
        uint256 minDuration = ah.MIN_DURATION();
        expectRevert("InvalidDuration()");
        ah.setDuration(minDuration - 1);

        // Reverts when duration is too high.
        uint256 maxDuration = ah.MAX_DURATION();
        expectRevert("InvalidDuration()");
        ah.setDuration(maxDuration + 1);

        // Emits expected `AuctionDurationSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionDurationSet(DURATION);
        ah.setDuration(DURATION);
    }

    function testUnpause() public {
        // Throws when unpaused by a non-admin.
        vm.startPrank(BIDDER);
        expectRevert("AdminOnly()");
        ah.unpause();
        
        vm.startPrank(ADMIN);
        // Remains paused if called for first time and minting fails.
        token.disableMinting();
        ah.unpause();
        vm.expectEmit(true, true, true, true);
        emit AuctionUnpaused(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit AuctionPaused(ADMIN);
        ah.unpause();

        token.enableMinting();

        // Unpauses and creates new auction when called first time successfully.
        vm.expectEmit(true, true, true, true);
        emit AuctionUnpaused(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(NFT, BLOCK_TIMESTAMP, BLOCK_TIMESTAMP + DURATION);
        ah.unpause();

        // Should throw when unpausing an ongoing auction.
        expectRevert("UnpausedAuction()");
        ah.unpause();
    }

    function testPause() public {
        // Reverts when trying to pause an already paused auction.
        expectRevert("PausedAuction()");
        ah.pause();

        ah.unpause();

        // Reverts when paused by a non-admin.
        vm.startPrank(BIDDER);
        expectRevert("AdminOnly()");
        ah.pause();

        // Should succesfully pause when called by admin.
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit AuctionPaused(ADMIN);
        ah.pause();
    }

    function testCreateBid() public {
        // Creating bid before auction creation throws.
        expectRevert("ExpiredAuction()");
        ah.createBid(NFT);

        ah.unpause();
        
        // Throws when bidding for an NFT not up for auction.
        expectRevert("NotUpForAuction()");
        ah.createBid(NFT + 1);

        // Throws when bidding without a value specified.
        expectRevert("BidTooLow()");
        ah.createBid(NFT);

        // Throws when bidding below reserve price.
        expectRevert("BidTooLow()");
        ah.createBid{ value: 0 }(NFT);

        // Throws when bidding after auction expiration.
        vm.warp(BLOCK_TIMESTAMP + DURATION + 1);
        expectRevert("ExpiredAuction()");
        ah.createBid(NFT);
        vm.warp(BLOCK_TIMESTAMP);

        // Successfully casts a bid.
        vm.startPrank(BIDDER);
        console.log("BEFORE");
        console.log(address(ah).balance);
        console.log(address(BIDDER).balance);
        ah.createBid{ value: 5 ether }(NFT);
        console.log(address(ah).balance);
        console.log(address(BIDDER).balance);
        console.log(BIDDER_INITIAL_BAL);
        assertTrue(false);

    }
}
