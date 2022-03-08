// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../governance/Timelock.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Timelock Test Suites
contract TimelockTest is Test {

    /// @notice Default timelock parameters.
    uint256 constant DELAY = 60 * 60 * 24 * 3; // 3 days

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    /// @notice Addresses used for testing.
    address constant FROM = address(99);
    address constant ADMIN = address(1337);

    /// @notice Timelock execution parameters.
    string constant SIGNATURE = "setDelay(uint256)";
    bytes constant CALLDATA = abi.encodeWithSignature("setDelay(uint256)", uint256(DELAY + 1));
    bytes constant REVERT_CALLDATA = abi.encodeWithSignature("setDelay(uint256)", uint256(0));
    bytes32 txHash;
    bytes32 revertTxHash;

    Timelock timelock;

    /// @notice Timelock events.
    event NewAdmin(address oldAdmin, address newAdmin);

    event NewPendingAdmin(address pendingAdmin);

	event DelaySet(uint256 delay);

	event CancelTransaction(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);
	event ExecuteTransaction(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);
	event QueueTransaction(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);


    function setUp() public {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        timelock = new Timelock(ADMIN, DELAY);
        txHash = keccak256(abi.encode(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY));
        revertTxHash = keccak256(abi.encode(address(timelock), 0, SIGNATURE, REVERT_CALLDATA, BLOCK_TIMESTAMP + DELAY));
        vm.startPrank(FROM);
        vm.deal(FROM, 8888);
    }

    function testConstructor() public {
        /// Reverts when setting invalid voting period.
        vm.expectRevert(InvalidDelay.selector);
        timelock = new Timelock(ADMIN, 0);

        vm.expectRevert(InvalidDelay.selector);
        timelock = new Timelock(ADMIN, 99999999999);

        timelock = new Timelock(ADMIN, DELAY);
        assertEq(timelock.delay(), DELAY);
        assertEq(timelock.admin(), ADMIN);
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function testReceive() public {
        (bool ok, ) = address(timelock).call{ value: 1 }(new bytes(0));
        assertTrue(ok);
    }

    function testFallback() public {
        (bool ok, ) = address(timelock).call{ value: 1 }("DEADBEEF");
        assertTrue(ok);
    }

    function testSetDelay() public {
        // Reverts when not set by the timelock.
        vm.expectRevert(TimelockOnly.selector);
        timelock.setDelay(DELAY);

        vm.startPrank(address(timelock));

        // Reverts when delay too small.
        uint256 minDelay = timelock.MIN_DELAY();
        vm.expectRevert(InvalidDelay.selector);
        timelock.setDelay(minDelay - 1);

        // Reverts when delay too large.
        uint256 maxDelay = timelock.MAX_DELAY();
        vm.expectRevert(InvalidDelay.selector);
        timelock.setDelay(maxDelay + 1);

        // Emits expected `DelaySet` event.
        vm.expectEmit(true, true, true, true);
        emit DelaySet(DELAY);
        timelock.setDelay(DELAY);

        assertEq(timelock.delay(), DELAY);
    }

    function testSetPendingAdmin() public {
        // Reverts when not set by the timelock.
        vm.expectRevert(TimelockOnly.selector);
        timelock.setPendingAdmin(FROM);

        vm.startPrank(address(timelock));

        // Emits the expected `NewPendingAdmin` event.
        vm.expectEmit(true, true, true, true);
        emit NewPendingAdmin(FROM);
        timelock.setPendingAdmin(FROM);

        assertEq(timelock.pendingAdmin(), FROM);
    }

    function testAcceptAdmin() public {
        // Reverts when caller is not the pending admin.
        vm.startPrank(address(timelock));
        timelock.setPendingAdmin(FROM);
        vm.expectRevert(PendingAdminOnly.selector);
        timelock.acceptAdmin();

        // Emits the expected `NewAdmin` event when executed by pending admin.
        vm.startPrank(FROM);
        vm.expectEmit(true, true, true, true);
        emit NewAdmin(ADMIN, FROM);
        timelock.acceptAdmin();

        // Properly assigns admin and clears pending admin.
        assertEq(timelock.admin(), FROM);
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function testQueueTransaction() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        
        // Reverts when the ETA is too soon.
        vm.expectRevert(PrematureTx.selector);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY - 1);

        assertTrue(!timelock.queuedTransactions(txHash));

        // Successfully emits the expected `QueueTransaction` event.
        vm.expectEmit(true, true, true, true);
        emit QueueTransaction(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        assertTrue(timelock.queuedTransactions(txHash));
    }

    function testCancelTransaction() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.cancelTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        assertTrue(timelock.queuedTransactions(txHash));

        // Successfully emits the expected `CancelTransaction` event.
        vm.expectEmit(true, true, true, true);
        emit CancelTransaction(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.cancelTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        assertTrue(!timelock.queuedTransactions(txHash));
    }

    function testExecuteTransaction() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        /// Queue two transactions, one which succeeds and one which reverts.
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, REVERT_CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when a call has not been previously queued.
        vm.expectRevert(UnqueuedTx.selector);
        timelock.executeTransaction(address(timelock), 1, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when ETA has yet to be reached.
        vm.warp(BLOCK_TIMESTAMP - 1);
        vm.expectRevert(PrematureTx.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when timelock ETA passes the grace period.
        vm.warp(BLOCK_TIMESTAMP + DELAY + timelock.GRACE_PERIOD() + 1);
        vm.expectRevert(StaleTx.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.warp(BLOCK_TIMESTAMP + DELAY);

        // Reverts when call fails.
        vm.expectRevert(RevertedTx.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, REVERT_CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Successfully emits the expected `ExecuteTransaction` event.
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        assertTrue(!timelock.queuedTransactions(txHash));
        assertEq(timelock.delay(), DELAY + 1);
    }
}
