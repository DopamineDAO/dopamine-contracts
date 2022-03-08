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
    uint256 constant DURATION = 60 * 60 * 12; // 12 hours

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    /// @notice Addresses used for testing.
    address constant ADMIN = address(1337);
    address constant BIDDER = address(99);
    address constant BIDDER_1 = address(89);
    address constant DAO = address(69);
    address constant RESERVE = address(1);

    MockDopamineAuctionHouseToken token;
    MockDopamineAuctionHouse ah;
    MockDopamineAuctionHouse ahImpl;

    uint256 constant BIDDER_INITIAL_BAL = 8888 ether;
    uint256 constant BIDDER_1_INITIAL_BAL = 10 ether;

    address payable reserve;
    address payable dao;
    MockMaliciousBidder MALICIOUS_BIDDER = new MockMaliciousBidder();
    MockGasBurner GAS_BURNER_BIDDER = new MockGasBurner();

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(ADMIN);

        vm.deal(BIDDER, BIDDER_INITIAL_BAL);
        vm.deal(BIDDER_1, BIDDER_1_INITIAL_BAL);
        vm.deal(address(MALICIOUS_BIDDER), 100 ether);
        vm.deal(address(GAS_BURNER_BIDDER), 100 ether);

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
        vm.expectRevert(AlreadyInitialized.selector);
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
        vm.expectRevert(InvalidTreasurySplit.selector);
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
        vm.expectRevert(InvalidTimeBuffer.selector);
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
        vm.expectRevert(InvalidReservePrice.selector);
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
        vm.expectRevert(InvalidDuration.selector);
		proxy = new ERC1967Proxy(address(ahImpl), data);
    }

    function testSetTreasurySplit() public {
        // Reverts when the treasury split is too high.
        vm.expectRevert(InvalidTreasurySplit.selector);
        ah.setTreasurySplit(101);

        // Emits expected `AuctionTreasurySplitSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTreasurySplitSet(TREASURY_SPLIT);
        ah.setTreasurySplit(TREASURY_SPLIT);
    }

    function testSetTimeBuffer() public {
        // Reverts when time buffer too small.
        uint256 minTimeBuffer = ah.MIN_TIME_BUFFER();
        vm.expectRevert(InvalidTimeBuffer.selector);
        ah.setTimeBuffer(minTimeBuffer - 1);

        // Reverts when time buffer too large.
        uint256 maxTimeBuffer = ah.MAX_TIME_BUFFER();
        vm.expectRevert(InvalidTimeBuffer.selector);
        ah.setTimeBuffer(maxTimeBuffer + 1);

        // Emits expected `AuctionTimeBufferSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionTimeBufferSet(TIME_BUFFER);
        ah.setTimeBuffer(TIME_BUFFER);
    }

    function testSetReservePrice() public {
        // Reverts when reserve price is too low.
        uint256 minReservePrice = ah.MIN_RESERVE_PRICE();
        vm.expectRevert(InvalidReservePrice.selector);
        ah.setReservePrice(minReservePrice - 1);

        // Reverts when reserve price is too high.
        uint256 maxReservePrice = ah.MAX_RESERVE_PRICE();
        vm.expectRevert(InvalidReservePrice.selector);
        ah.setReservePrice(maxReservePrice + 1);

        // Emits expected `AuctionReservePriceSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionReservePriceSet(RESERVE_PRICE);
        ah.setReservePrice(RESERVE_PRICE);
    }

    function testSetDuration() public {
        // Reverts when duration is too low.
        uint256 minDuration = ah.MIN_DURATION();
        vm.expectRevert(InvalidDuration.selector);
        ah.setDuration(minDuration - 1);

        // Reverts when duration is too high.
        uint256 maxDuration = ah.MAX_DURATION();
        vm.expectRevert(InvalidDuration.selector);
        ah.setDuration(maxDuration + 1);

        // Emits expected `AuctionDurationSet` event.
        vm.expectEmit(true, true, true, true);
        emit AuctionDurationSet(DURATION);
        ah.setDuration(DURATION);
    }

    function testUnpause() public {
        // Throws when unpaused by a non-admin.
        vm.startPrank(BIDDER);
        vm.expectRevert(AdminOnly.selector);
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
        vm.expectRevert(UnpausedAuction.selector);
        ah.unpause();
    }

    function testPause() public {
        // Reverts when trying to pause an already paused auction.
        vm.expectRevert(PausedAuction.selector);
        ah.pause();

        ah.unpause();

        // Reverts when paused by a non-admin.
        vm.startPrank(BIDDER);
        vm.expectRevert(AdminOnly.selector);
        ah.pause();

        // Should succesfully pause when called by admin.
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit AuctionPaused(ADMIN);
        ah.pause();
    }

    function testCreateBid() public {
        // Creating bid before auction creation throws.
        vm.expectRevert(ExpiredAuction.selector);
        ah.createBid(NFT);

        ah.unpause();
        
        // Throws when bidding for an NFT not up for auction.
        vm.expectRevert(NotUpForAuction.selector);
        ah.createBid(NFT + 1);

        // Throws when bidding without a value specified.
        vm.expectRevert(BidTooLow.selector);
        ah.createBid(NFT);

        // Throws when bidding below reserve price.
        vm.expectRevert(BidTooLow.selector);
        ah.createBid{ value: 0 }(NFT);

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
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        // Throws when bidding less than 5% of previous bid.
        vm.expectRevert(BidTooLow.selector);
        ah.createBid{ value: 1 ether * 104 / 100 }(NFT);

        // Min time to forward for time extension to apply.
        uint256 et = BLOCK_TIMESTAMP + DURATION - TIME_BUFFER + 1;
        vm.warp(et);
        vm.startPrank(BIDDER_1);

        // Auctions get successfully extended if applicable.
        vm.expectEmit(true, true, true, true);
        emit AuctionExtended(NFT, et + TIME_BUFFER);
        vm.expectEmit(true, true, true, true);
        emit AuctionBid(NFT, BIDDER_1, 2 ether, true);
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
        // Keeps eth and notifies via event in case of failed refunds.
        vm.startPrank(address(MALICIOUS_BIDDER));
        ah.createBid{ value: 4 ether }(NFT);
        vm.startPrank(BIDDER);
        vm.expectEmit(true, true, true, true);
        emit RefundFailed(address(MALICIOUS_BIDDER));
        ah.createBid{ value: 8 ether }(NFT);
        assertEq(address(ah).balance, 12 ether);

        // Check malicious gas burner bidders cannot exploit auction.
        vm.startPrank(address(GAS_BURNER_BIDDER));
        ah.createBid{ value: 9 ether }(NFT);
        vm.startPrank(BIDDER);
        uint256 gasStart = gasleft();
        vm.expectEmit(true, true, true, true);
        emit RefundFailed(address(GAS_BURNER_BIDDER));
        ah.createBid{ value: 10 ether }(NFT);
        uint256 gasEnd = gasleft();
        assertLt(gasStart - gasEnd, 150000);
        
        // Throws when bidding after auction expiration.
        vm.warp(et + TIME_BUFFER + 1);
        vm.expectRevert(ExpiredAuction.selector);
        ah.createBid(NFT);
    }

    function testSettleAuction() public {
        // Reverts when settling before auction commencement.
        vm.expectRevert(UncommencedAuction.selector);
        ah.settleAuction();

        ah.unpause();

        // Reverts when settling while auction is not paused.
        vm.expectRevert(UnpausedAuction.selector);
        ah.settleAuction();
        ah.pause();

        vm.startPrank(BIDDER);

        // Reverts when settling an auction not yet settled.
        vm.expectRevert(IncompleteAuction.selector);
        ah.settleAuction();

        // Transfers NFT to DAO when there were no bidders.
        vm.warp(BLOCK_TIMESTAMP + DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT, address(0), 0);
        ah.settleAuction();
        assertEq(token.ownerOf(NFT), address(dao));

        // Relevant attributes appropriately updated.
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 0 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.bidder, address(0));
        assertTrue(auction.settled);

        // Settling already settled auction reverts.
        vm.expectRevert(AlreadySettled.selector);
        ah.settleAuction();

        vm.startPrank(ADMIN);
        ah.unpause();

        // Settling awards NFT to last bidder.
        vm.startPrank(BIDDER);
        ah.createBid{ value: 1 ether }(NFT_1);
        vm.startPrank(ADMIN);
        ah.pause();
        vm.warp(BLOCK_TIMESTAMP + DURATION * 2);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT_1, BIDDER, 1 ether);
        ah.settleAuction();
        assertEq(token.ownerOf(NFT_1), BIDDER);

        // Revenue appropriately allocated to dao and reserve.
        uint256 treasuryProceeds = 1 ether * TREASURY_SPLIT / 100;
        assertEq(dao.balance, treasuryProceeds);
        assertEq(reserve.balance, 1 ether - treasuryProceeds);

        // Relevant attributes appropriately updated.
        auction = ah.getAuction();
        assertEq(auction.tokenId, NFT_1);
        assertEq(auction.amount, 1 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION * 2);
        assertEq(auction.bidder, BIDDER);
        assertTrue(auction.settled);
    }

    function testSettleCurrentAndCreateNewAuction() public {
        // Reverts when auction is paused.
        vm.expectRevert(PausedAuction.selector);
        ah.settleCurrentAndCreateNewAuction();

        ah.unpause(); 

        // Reverts when settling an auction not yet settled.
        vm.expectRevert(IncompleteAuction.selector);
        ah.settleCurrentAndCreateNewAuction();

        // Settles new auction and creates a new one.
        vm.startPrank(BIDDER);
        ah.createBid{ value: 1 ether }(NFT);
        vm.warp(BLOCK_TIMESTAMP + DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT, BIDDER, 1 ether);
        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(NFT_1, BLOCK_TIMESTAMP + DURATION, BLOCK_TIMESTAMP + 2 * DURATION);
        ah.settleCurrentAndCreateNewAuction();

        // NFT awarded to last bidder.
        assertEq(token.ownerOf(NFT), BIDDER);

        // Proceeds distributed.
        uint256 treasuryProceeds = 1 ether * TREASURY_SPLIT / 100;
        assertEq(dao.balance, treasuryProceeds);
        assertEq(reserve.balance, 1 ether - treasuryProceeds);

        // Relevant attributes appropriately updated.
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT_1);
        assertEq(auction.amount, 0 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION * 2);
        assertEq(auction.bidder, address(0));
        assertTrue(!auction.settled);

        // Settles current auction and pauses in case next NFT mint fails.
        vm.warp(BLOCK_TIMESTAMP + DURATION * 2);
        token.disableMinting();
        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(NFT_1, address(0), 0 ether);
        vm.expectEmit(true, true, true, true);
        emit AuctionPaused(BIDDER);
        ah.settleCurrentAndCreateNewAuction();
        
        // No bids here - check NFT transferred to the DAO.
        assertEq(token.ownerOf(NFT_1), address(dao));
    }

    function testUpgrade() public {
        // Setup upgrade to be performed during live auction.
        ah.unpause();
        vm.startPrank(BIDDER);
        ah.createBid{ value: 2 ether }(NFT);
        IDopamineAuctionHouse.Auction memory auction = ah.getAuction();
        assertEq(auction.tokenId, NFT);
        assertEq(auction.amount, 2 ether);
        assertEq(auction.startTime, BLOCK_TIMESTAMP);
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        MockDopamineAuctionHouseUpgraded upgradedImpl = new MockDopamineAuctionHouseUpgraded();
        
        // Upgrades should not work if called by unauthorized upgrader.
        vm.startPrank(BIDDER);
        vm.expectRevert(UnauthorizedUpgrade.selector);
        ah.upgradeTo(address(upgradedImpl));

        // Perform an upgrade that initializes with faulty dao and reserve.
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
        assertEq(auction.endTime, BLOCK_TIMESTAMP + DURATION);
        assertEq(auction.bidder, BIDDER);
        assertTrue(!auction.settled);

        // Check that re-initialized parameters were updated.
        assertEq(ahUpgraded.dao(), faultyDao);
        assertEq(ahUpgraded.reserve(), faultyReserve);

        // Settle auction and check funds remain in auction contract.
        vm.warp(BLOCK_TIMESTAMP + DURATION);
        ahUpgraded.settleCurrentAndCreateNewAuction();
        assertEq(faultyDao.balance, 0);
        assertEq(faultyReserve.balance, 0);
        assertEq(address(ahUpgraded).balance, 2 ether);

        // Ensure new functions can be called.
        ahUpgraded.setDAO(dao);
        ahUpgraded.setReserve(reserve);

        // Withdraw funds with upgraded contract.
        ahUpgraded.withdraw();
        assertEq(dao.balance, 2 ether);
    }

    function testImplementationUnusable() public {
        // Implementation cannot be re-initialized.
        vm.expectRevert("Function must be called through delegatecall");
        ahImpl.initialize(
            address(token),
            reserve,
            dao,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            DURATION
        );

        // Other actions fail due to faulty implementation initialization.
        vm.startPrank(BIDDER);
        vm.expectRevert(Reentrant.selector);
        ahImpl.createBid{ value: 1 ether }(NFT);
    }


}
