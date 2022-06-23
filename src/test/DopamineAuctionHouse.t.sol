// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./mocks/MockDopamineAuctionHouse.sol";
import "./mocks/MockDopamineAuctionHouseUpgraded.sol";
import "./mocks/MockMaliciousBidder.sol";
import "./mocks/MockGasBurner.sol";
import "./mocks/MockDopamineAuctionHouseToken.sol";
import "../auction/DopamineAuctionHouse.sol";
import "../interfaces/IDopamineAuctionHouse.sol";

import "./utils/test.sol";
import "./utils/console.sol";

contract MockContractUnpayable { }
contract MockContractPayable { receive() external payable {} }

/// @title Dopamine Auction Test Suites
contract DopamineAuctionHouseTest is Test, IDopamineAuctionHouseEvents {

    bool constant PROXY = true;

    uint256 constant NFT = 0;
    uint256 constant NFT_1 = 1;

    /// @notice Default auction house parameters.
    uint256 constant TREASURY_SPLIT = 30; // 50%
    uint256 constant TIME_BUFFER = 10 minutes;
    uint256 constant RESERVE_PRICE = 1 ether;
    uint256 constant AUCTION_DURATION = 60 * 60 * 12; // 12 hours

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    /// @notice Addresses used for testing.
    address constant ADMIN = address(1337);
    address constant BIDDER = address(99);
    address constant BIDDER_1 = address(89);
    address constant TREASURY = address(69);
    address constant RESERVE = address(1);

    MockDopamineAuctionHouseToken token;
    MockDopamineAuctionHouse ah;
    MockDopamineAuctionHouse ahImpl;

    uint256 constant BIDDER_INITIAL_BAL = 8888 ether;
    uint256 constant BIDDER_1_INITIAL_BAL = 10 ether;

    address payable reserve;
    address payable treasury;
    MockMaliciousBidder MALICIOUS_BIDDER = new MockMaliciousBidder();
    MockGasBurner GAS_BURNER_BIDDER = new MockGasBurner();

    uint256 public constant MIN_AUCTION_BUFFER = 60 seconds;
    uint256 public constant MAX_AUCTION_BUFFER = 24 hours;
    uint256 public constant MIN_RESERVE_PRICE = 1 wei;
    uint256 public constant MAX_RESERVE_PRICE = 99 ether;
    uint256 public constant MIN_AUCTION_DURATION = 10 minutes;
    uint256 public constant MAX_AUCTION_DURATION = 1 weeks;

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(ADMIN);

        vm.deal(BIDDER, BIDDER_INITIAL_BAL);
        vm.deal(BIDDER_1, BIDDER_1_INITIAL_BAL);
        vm.deal(address(MALICIOUS_BIDDER), 100 ether);
        vm.deal(address(GAS_BURNER_BIDDER), 100 ether);

        reserve = payable(address(new MockContractPayable()));
        treasury = payable(address(new MockContractPayable()));
        ahImpl = new MockDopamineAuctionHouse();
        address proxyAddr = getContractAddress(address(ADMIN), 0x04); 

        token = new MockDopamineAuctionHouseToken(proxyAddr, 99);
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            AUCTION_DURATION
        );
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);
        ah = MockDopamineAuctionHouse(address(proxy));
        vm.stopPrank();
    }

    function testInitialize() public {
        vm.startPrank(ADMIN);
        /// Correctly sets all auction house parameters.
        assertEq(address(ah.token()), address(token));
        assertEq(ah.pendingAdmin(), address(0));
        assertEq(ah.admin(), ADMIN);
        assertEq(ah.auctionBuffer(), TIME_BUFFER);
        assertEq(ah.reservePrice(), RESERVE_PRICE);
        assertEq(ah.treasurySplit(), TREASURY_SPLIT);
        assertEq(ah.auctionDuration(), AUCTION_DURATION);
        assertEq(ah.treasury(), treasury);
        assertEq(ah.reserve(), reserve);
        assertTrue(ah.suspended());

        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, 0);
        assertEq(auction.amount, 0);
        assertEq(auction.startTime, 0);
        assertEq(auction.endTime, 0);
        assertEq(auction.bidder, address(0));
        assertTrue(auction.settled);

        /// Reverts when trying to initialize more than once.
        vm.expectRevert(ContractAlreadyInitialized.selector);
        ah.initialize(
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            AUCTION_DURATION
        );

        /// Reverts when setting invalid treasury split.
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            101,
            TIME_BUFFER,
            RESERVE_PRICE,
            AUCTION_DURATION
        );
        vm.expectRevert(AuctionTreasurySplitInvalid.selector);
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid time buffer.
        uint256 invalidParam = ah.MIN_AUCTION_BUFFER() - 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            invalidParam,
            RESERVE_PRICE,
            AUCTION_DURATION
        );
        vm.expectRevert(AuctionBufferInvalid.selector);
		proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid reserve price.
        invalidParam = ah.MAX_RESERVE_PRICE() + 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            TIME_BUFFER,
            invalidParam,
            AUCTION_DURATION
        );
        vm.expectRevert(AuctionReservePriceInvalid.selector);
		proxy = new ERC1967Proxy(address(ahImpl), data);

        /// Reverts when setting an invalid duration.
        invalidParam = ah.MIN_AUCTION_DURATION() - 1;
        data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            invalidParam
        );
        vm.expectRevert(AuctionDurationInvalid.selector);
		proxy = new ERC1967Proxy(address(ahImpl), data);
        vm.stopPrank();
    }

    function testSetTreasurySplit() public {
        vm.startPrank(ADMIN);
        // Reverts when the treasury split is too high.
        vm.expectRevert(AuctionTreasurySplitInvalid.selector);
        ah.setTreasurySplit(101);

        // Emits expected `AuctionTreasurySplitSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTreasurySplitSet(TREASURY_SPLIT);
        ah.setTreasurySplit(TREASURY_SPLIT);
        vm.stopPrank();
    }

    function testSetTimeBuffer() public {
        vm.startPrank(ADMIN);
        // Reverts when time buffer too small.
        uint256 minTimeBuffer = ah.MIN_AUCTION_BUFFER();
        vm.expectRevert(AuctionBufferInvalid.selector);
        ah.setAuctionBuffer(minTimeBuffer - 1);

        // Reverts when time buffer too large.
        uint256 maxTimeBuffer = ah.MAX_AUCTION_BUFFER();
        vm.expectRevert(AuctionBufferInvalid.selector);
        ah.setAuctionBuffer(maxTimeBuffer + 1);

        // Emits expected `AuctionBufferSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionBufferSet(TIME_BUFFER);
        ah.setAuctionBuffer(TIME_BUFFER);
        vm.stopPrank();
    }

    function testSetReservePrice() public {
        vm.startPrank(ADMIN);
        // Reverts when reserve price is too low.
        uint256 minReservePrice = ah.MIN_RESERVE_PRICE();
        vm.expectRevert(AuctionReservePriceInvalid.selector);
        ah.setReservePrice(minReservePrice - 1);

        // Reverts when reserve price is too high.
        uint256 maxReservePrice = ah.MAX_RESERVE_PRICE();
        vm.expectRevert(AuctionReservePriceInvalid.selector);
        ah.setReservePrice(maxReservePrice + 1);

        // Emits expected `AuctionReservePriceSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionReservePriceSet(RESERVE_PRICE);
        ah.setReservePrice(RESERVE_PRICE);
        vm.stopPrank();
    }

    function testSetAuctionDuration() public {
        vm.startPrank(ADMIN);
        // Reverts when duration is too low.
        uint256 minAuctionDuration = ah.MIN_AUCTION_DURATION();
        vm.expectRevert(AuctionDurationInvalid.selector);
        ah.setAuctionDuration(minAuctionDuration - 1);

        // Reverts when duration is too high.
        uint256 maxAuctionDuration = ah.MAX_AUCTION_DURATION();
        vm.expectRevert(AuctionDurationInvalid.selector);
        ah.setAuctionDuration(maxAuctionDuration + 1);

        // Emits expected `AuctionDurationSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionDurationSet(AUCTION_DURATION);
        ah.setAuctionDuration(AUCTION_DURATION);
        vm.stopPrank();
    }

    function testResumeNewAuctions() public {
        // Throws when resumed by a non-admin.
        vm.startPrank(BIDDER);
        vm.expectRevert(AdminOnly.selector);
        ah.resumeNewAuctions();
        
        vm.stopPrank();
        vm.startPrank(ADMIN);

        // Remains suspended if called for first time and minting fails.
        token.disableMinting();
        vm.expectEmit(true, true, true, true);
        emit AuctionCreationFailed();
        ah.resumeNewAuctions();
        assertTrue(ah.suspended());

        token.enableMinting();

        // Unpauses and creates new auction when called first time successfully.
        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(NFT, BLOCK_TIMESTAMP, BLOCK_TIMESTAMP + AUCTION_DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionResumed();
        ah.resumeNewAuctions();

        // Should throw when resuming an ongoing auction.
        vm.expectRevert(AuctionNotSuspended.selector);
        ah.resumeNewAuctions();

        // Suspend new auctions and settle current.
        ah.suspendNewAuctions();
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION);
        ah.settleAuction();
        assertTrue(ah.suspended());

        // Remains suspended if current auction is settled but minting fails.
        token.disableMinting();
        vm.expectEmit(true, true, true, true);
        emit AuctionCreationFailed();
        ah.resumeNewAuctions();
        assertTrue(ah.suspended());
        vm.stopPrank();

    }

    function testSuspendNewAuctions() public {
        vm.startPrank(ADMIN);
        // Reverts when trying to suspend an already suspended auction.
        vm.expectRevert(AuctionAlreadySuspended.selector);
        ah.suspendNewAuctions();

        ah.resumeNewAuctions();
        vm.stopPrank();

        // Reverts when suspended by a non-admin.
        vm.startPrank(BIDDER);
        vm.expectRevert(AdminOnly.selector);
        ah.suspendNewAuctions();
        vm.stopPrank();

        // Should succesfully suspended when called by admin.
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit AuctionSuspended();
        ah.suspendNewAuctions();
        assertTrue(ah.suspended());
    }

    function testCreateBid() public {
        vm.startPrank(ADMIN);
        // Creating bid before auction creation throws.
        vm.expectRevert(AuctionExpired.selector);
        ah.createBid(NFT);

        ah.resumeNewAuctions();
        
        // Throws when bidding for an NFT not up for auction.
        vm.expectRevert(AuctionBidInvalid.selector);
        ah.createBid(NFT + 1);

        // Throws when bidding without a value specified.
        vm.expectRevert(AuctionBidTooLow.selector);
        ah.createBid(NFT);

        // Throws when bidding below reserve price.
        vm.expectRevert(AuctionBidTooLow.selector);
        ah.createBid{ value: 0 }(NFT);
        vm.stopPrank();

        // Successfully creates a bid.
        vm.startPrank(BIDDER);
        vm.expectEmit(true, true, true, true);
        emit AuctionBid(NFT, BIDDER, 1 ether, false);
        ah.createBid{ value: 1 ether }(NFT);
        assertEq(BIDDER.balance, BIDDER_INITIAL_BAL - 1 ether);

        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 1 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        // Throws when bidding less than 5% of previous bid.
        vm.expectRevert(AuctionBidTooLow.selector);
        ah.createBid{ value: 1 ether * 104 / 100 }(NFT);

        // Min time to forward for time extension to apply.
        uint256 et = BLOCK_TIMESTAMP + AUCTION_DURATION - TIME_BUFFER + 1;
        vm.warp(et);
        vm.stopPrank();
        vm.startPrank(BIDDER_1);

        // Auctions get successfully extended if applicable.
        vm.expectEmit(true, true, true, true);
        emit AuctionBid(NFT, BIDDER_1, 2 ether, true);
        vm.expectEmit(true, true, true, true);
        emit AuctionExtended(NFT, et + TIME_BUFFER);
        ah.createBid{ value: 2 ether }(NFT);

        // Auction attributes also get updated.
        auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 2 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, et + TIME_BUFFER);
        assertEq(auction.bidder, BIDDER_1);
        assertTrue(!auction.settled);

        // Refunds the previous bidder.
        assertEq(BIDDER.balance, BIDDER_INITIAL_BAL);
        assertEq(BIDDER_1.balance, BIDDER_1_INITIAL_BAL - 2 ether);
        vm.stopPrank();
        // Keeps eth and notifies via event in case of failed refunds.
        vm.startPrank(address(MALICIOUS_BIDDER));
        ah.createBid{ value: 4 ether }(NFT);
        vm.stopPrank();
        vm.startPrank(BIDDER);
        vm.expectEmit(true, true, true, true);
        emit RefundFailed(address(MALICIOUS_BIDDER));
        ah.createBid{ value: 8 ether }(NFT);
        assertEq(address(ah).balance, 8 ether);
        vm.stopPrank();

        // Check malicious gas burner bidders cannot exploit auction.
        vm.startPrank(address(GAS_BURNER_BIDDER));
        ah.createBid{ value: 9 ether }(NFT);
        vm.stopPrank();
        vm.startPrank(BIDDER);
        uint256 gasStart = gasleft();
        vm.expectEmit(true, true, true, true);
        emit RefundFailed(address(GAS_BURNER_BIDDER));
        ah.createBid{ value: 10 ether }(NFT);
        uint256 gasEnd = gasleft();
        assertLt(gasStart - gasEnd, 150000);
        
        // Throws when bidding after auction expiration.
        vm.warp(et + TIME_BUFFER + 1);
        vm.expectRevert(AuctionExpired.selector);
        ah.createBid(NFT);
        vm.stopPrank();
    }

    function testSettleAuctionWhenSuspended() public {
        vm.startPrank(ADMIN);

        // [TESTS SETTLEMENT WHEN SUSPENDED] 

        // Reverts when settling before any auctions commence.
        vm.expectRevert(AuctionAlreadySettled.selector);
        ah.settleAuction();

        ah.resumeNewAuctions(); // Put NFT up for auction.
        ah.suspendNewAuctions(); // Suspend future NFTs from getting auctioned.

        vm.stopPrank();
        vm.startPrank(BIDDER);

        // Reverts when settling an auction not yet settled.
        vm.expectRevert(AuctionOngoing.selector);
        ah.settleAuction();

        // Transfers NFT to TREASURY when there were no bidders.
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT, address(0), 0);
        ah.settleAuction();
        assertEq(token.ownerOf(NFT), address(treasury));

        // Relevant attributes appropriately updated.
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 0 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.bidder, address(0));
        assertTrue(auction.settled);

        // Settling already settled auction reverts.
        vm.expectRevert(AuctionAlreadySettled.selector);
        ah.settleAuction();

        vm.stopPrank();
        vm.startPrank(ADMIN);
        ah.resumeNewAuctions();

        // Settling awards NFT to last bidder.
        vm.stopPrank();
        vm.startPrank(BIDDER);
        ah.createBid{ value: 1 ether }(NFT_1);
        vm.stopPrank();
        vm.startPrank(ADMIN);
        ah.suspendNewAuctions();
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION * 2);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT_1, BIDDER, 1 ether);
        ah.settleAuction();
        assertEq(token.ownerOf(NFT_1), BIDDER);

        // Revenue appropriately allocated to treasury and reserve.
        uint256 treasuryProceeds = 1 ether * TREASURY_SPLIT / 100;
        assertEq(treasury.balance, treasuryProceeds);
        assertEq(reserve.balance, 1 ether - treasuryProceeds);

        // Relevant attributes appropriately updated.
        auction = ah.getAuction();
        assertEq(auction.tokenId, NFT_1);
        assertEq(auction.amount, 1 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION * 2);
        assertEq(auction.bidder, BIDDER);
        assertTrue(auction.settled);
    }

    function testSettleAuctionWhenLive() public {
        vm.startPrank(ADMIN);
        // [TESTS SETTLEMENT WHEN NOT SUSPENDED]
        ah.resumeNewAuctions(); 

        // Reverts when settling an auction not yet settled.
        vm.expectRevert(AuctionOngoing.selector);
        ah.settleAuction();

        // Settles new auction and creates a new one.
        vm.stopPrank();
        vm.startPrank(BIDDER);
        ah.createBid{ value: 1 ether }(NFT);
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT, BIDDER, 1 ether);
        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(NFT_1, BLOCK_TIMESTAMP + AUCTION_DURATION, BLOCK_TIMESTAMP + 2 * AUCTION_DURATION);
        ah.settleAuction();

        // NFT awarded to last bidder.
        assertEq(token.ownerOf(NFT), BIDDER);

        // Proceeds distributed.
        uint256 treasuryProceeds = 1 ether * TREASURY_SPLIT / 100;
        assertEq(treasury.balance, treasuryProceeds);
        assertEq(reserve.balance, 1 ether - treasuryProceeds);

        // Relevant attributes appropriately updated.
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT_1);
        assertEq(auction.amount, 0 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION * 2);
        assertEq(auction.bidder, address(0));
        assertTrue(!auction.settled);

        // Settles current auction and pauses in case next NFT mint fails.
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION * 2);
        token.disableMinting();
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT_1, address(0), 0 ether);
        vm.expectEmit(true, true, true, true);
        emit AuctionCreationFailed();
        vm.expectEmit(true, true, true, true);
        emit AuctionSuspended();
        ah.settleAuction();
        
        // No bids here - check NFT transferred to the TREASURY.
        assertEq(token.ownerOf(NFT_1), address(treasury));
        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(ADMIN);
        // Setup upgrade to be performed during live auction.
        ah.resumeNewAuctions();
        vm.stopPrank();
        vm.startPrank(BIDDER);
        ah.createBid{ value: 2 ether }(NFT);
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 2 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        MockDopamineAuctionHouseUpgraded upgradedImpl = new MockDopamineAuctionHouseUpgraded();
        vm.stopPrank();
        
        // Upgrades should not work if called by unauthorized upgrader.
        vm.startPrank(BIDDER);
        vm.expectRevert(UpgradeUnauthorized.selector);
        ah.upgradeTo(address(upgradedImpl));
        vm.stopPrank();

        // Perform an upgrade that initializes with faulty treasury and reserve.
        vm.startPrank(ADMIN);
        address faultyReserve = address(new MockContractUnpayable());
        address faultyDao = address(new MockContractUnpayable());
        bytes memory data = abi.encodeWithSelector(
            upgradedImpl.initializeV2.selector,
            faultyReserve,
            faultyDao
        );
        ah.upgradeToAndCall(address(upgradedImpl), data);
        MockDopamineAuctionHouseUpgraded ahUpgraded = MockDopamineAuctionHouseUpgraded(address(ah));

        // Check existing auction parameters remain the same.
        auction = ahUpgraded.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 2 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + AUCTION_DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        // Check that re-initialized parameters were updated.
        assertEq(ahUpgraded.treasury(), faultyDao);
        assertEq(ahUpgraded.reserve(), faultyReserve);
        assertEq(ahUpgraded.treasury2(), address(ahUpgraded));
        assertEq(ahUpgraded.reserve2(), address(ahUpgraded));

        // Settle auction and check funds remain in auction contract.
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION);
        ahUpgraded.settleAuction();
        assertEq(faultyDao.balance, 0);
        assertEq(faultyReserve.balance, 0);
        assertEq(address(ahUpgraded).balance, 2 ether);

        // Ensure new functions can be called.
        ahUpgraded.setTreasury2(treasury);
        ahUpgraded.setReserve2(reserve);

        // Withdraw funds with upgraded contract.
        ahUpgraded.withdraw();
        assertEq(treasury.balance, 2 ether);
    }

    function testImplementationUnusable() public {
        // Implementation cannot be re-initialized.
        vm.expectRevert("Function must be called through delegatecall");
        ahImpl.initialize(
            address(token),
            reserve,
            treasury,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            AUCTION_DURATION
        );

        // Other actions fail due to faulty implementation initialization.
        vm.stopPrank();
        vm.startPrank(BIDDER);
        vm.expectRevert(FunctionReentrant.selector);
        ahImpl.createBid{ value: 1 ether }(NFT);

        vm.expectRevert(FunctionReentrant.selector);
        ahImpl.settleAuction();
        vm.stopPrank();
    }

    function testFuzzInitialize(uint96 treasurySplit, uint256 timeBuffer, uint256 reservePrice, uint256 auctionDuration) public {
        vm.assume(treasurySplit <= 100);
        vm.assume(timeBuffer >= MIN_AUCTION_BUFFER);
        vm.assume(timeBuffer <= MAX_AUCTION_BUFFER);
        // vm.assume(reservePrice >= MIN_RESERVE_PRICE);
        // vm.assume(reservePrice <= MAX_RESERVE_PRICE);
        // vm.assume(auctionDuration >= MIN_AUCTION_DURATION);
        // vm.assume(auctionDuration <= MIN_AUCTION_DURATION);

        vm.startPrank(ADMIN);

        if (reservePrice < MIN_RESERVE_PRICE || reservePrice > MAX_RESERVE_PRICE) {
            vm.expectRevert(AuctionReservePriceInvalid.selector);
        } else if (auctionDuration < MIN_AUCTION_DURATION || auctionDuration > MAX_AUCTION_DURATION) {
            vm.expectRevert(AuctionDurationInvalid.selector);
        }
        
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            reserve,
            treasury,
            treasurySplit,
            timeBuffer,
            reservePrice,
            auctionDuration
        );
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);
        
        vm.stopPrank();
    }

    function testFuzzSetTreasurySplit(uint256 newTreasurySplit) public {
        vm.assume(newTreasurySplit <= 100);

        vm.startPrank(ADMIN);
        // Emits expected `AuctionTreasurySplitSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTreasurySplitSet(newTreasurySplit);
        ah.setTreasurySplit(newTreasurySplit);
        vm.stopPrank();
    }

    function testFuzzCreateBid(uint256 bidAmount) public {
        vm.assume(bidAmount <= 10 ether);
        vm.startPrank(ADMIN);
        ah.resumeNewAuctions();
        vm.stopPrank();

        vm.startPrank(BIDDER);
        if (bidAmount < 1 ether) {
            vm.expectRevert(AuctionBidTooLow.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit AuctionBid(NFT, BIDDER, bidAmount, false);
        }

        ah.createBid{ value: bidAmount }(NFT);
        vm.stopPrank();
    }
}
