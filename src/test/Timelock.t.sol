// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../governance/Timelock.sol";
import "../interfaces/ITimelockEvents.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Timelock Test Suites
contract TimelockTest is Test, ITimelockEvents {

    /// @notice Default timelock parameters.
    uint256 constant DELAY = 60 * 60 * 24 * 3; // 3 days

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    /// @notice Addresses used for testing.
    address constant FROM = address(99);
    address constant ADMIN = address(1337);

    /// @notice Timelock execution parameters.
    string constant SIGNATURE = "setTimelockDelay(uint256)";
    bytes constant CALLDATA = abi.encodeWithSignature("setTimelockDelay(uint256)", uint256(DELAY + 1));
    bytes constant REVERT_CALLDATA = abi.encodeWithSignature("setTimelockDelay(uint256)", uint256(0));
    bytes32 txHash;
    bytes32 revertTxHash;

    Timelock timelock;

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
        vm.expectRevert(TimelockDelayInvalid.selector);
        timelock = new Timelock(ADMIN, 0);

        vm.expectRevert(TimelockDelayInvalid.selector);
        timelock = new Timelock(ADMIN, 99999999999);

        timelock = new Timelock(ADMIN, DELAY);
        assertEq(timelock.timelockDelay(), DELAY);
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

    function testSetTimelockDelay() public {
        // Reverts when not set by the timelock.
        vm.expectRevert(TimelockOnly.selector);
        timelock.setTimelockDelay(DELAY);

        vm.startPrank(address(timelock));

        // Reverts when delay too small.
        uint256 minDelay = timelock.MIN_TIMELOCK_DELAY();
        vm.expectRevert(TimelockDelayInvalid.selector);
        timelock.setTimelockDelay(minDelay - 1);

        // Reverts when delay too large.
        uint256 maxDelay = timelock.MAX_TIMELOCK_DELAY();
        vm.expectRevert(TimelockDelayInvalid.selector);
        timelock.setTimelockDelay(maxDelay + 1);

        // Emits expected `DelaySet` event.
        vm.expectEmit(true, true, true, true);
        emit TimelockDelaySet(DELAY);
        timelock.setTimelockDelay(DELAY);

        assertEq(timelock.timelockDelay(), DELAY);
    }

    function testSetPendingAdmin() public {
        // Reverts when not set by the timelock.
        vm.expectRevert(TimelockOnly.selector);
        timelock.setPendingAdmin(FROM);

        vm.startPrank(address(timelock));

        // Emits the expected `PendingAdminSet` event.
        vm.expectEmit(true, true, true, true);
        emit PendingAdminSet(FROM);
        timelock.setPendingAdmin(FROM);

        assertEq(timelock.pendingAdmin(), FROM);
    }

    function testAcceptAdmin() public {
        // Reverts when caller is not the pending admin.
        vm.startPrank(address(timelock));
        timelock.setPendingAdmin(FROM);
        vm.expectRevert(PendingAdminOnly.selector);
        timelock.acceptAdmin();

        // Emits the expected `AdminChanged` event when executed by pending admin.
        vm.startPrank(FROM);
        vm.expectEmit(true, true, true, true);
        emit AdminChanged(ADMIN, FROM);
        timelock.acceptAdmin();

        // Properly assigns admin and clears pending admin.
        assertEq(timelock.admin(), FROM);
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function testTransactionQueued() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        
        // Reverts when the ETA is too soon.
        vm.expectRevert(TransactionPremature.selector);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY - 1);

        assertTrue(!timelock.queuedTransactions(txHash));

        // Successfully emits the expected `TransactionQueued` event.
        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        assertTrue(timelock.queuedTransactions(txHash));
    }

    function testTransactionCanceled() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.cancelTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        assertTrue(timelock.queuedTransactions(txHash));

        // Successfully emits the expected `TransactionCanceled` event.
        vm.expectEmit(true, true, true, true);
        emit TransactionCanceled(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.cancelTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        assertTrue(!timelock.queuedTransactions(txHash));
    }

    function testTransactionExecuted() public {
        // Reverts when not called by the admin.
        vm.expectRevert(AdminOnly.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.startPrank(ADMIN);
        /// Queue two transactions, one which succeeds and one which reverts.
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.queueTransaction(address(timelock), 0, SIGNATURE, REVERT_CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when a call has not been previously queued.
        vm.expectRevert(TransactionNotYetQueued.selector);
        timelock.executeTransaction(address(timelock), 1, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when ETA has yet to be reached.
        vm.warp(BLOCK_TIMESTAMP - 1);
        vm.expectRevert(TransactionPremature.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Reverts when timelock ETA passes the grace period.
        vm.warp(BLOCK_TIMESTAMP + DELAY + timelock.GRACE_PERIOD() + 1);
        vm.expectRevert(TransactionStale.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);

        vm.warp(BLOCK_TIMESTAMP + DELAY);

        // Reverts when call fails.
        vm.expectRevert(TransactionReverted.selector);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, REVERT_CALLDATA, BLOCK_TIMESTAMP + DELAY);

        // Successfully emits the expected `TransactionExecuted` event.
        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(txHash, address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        timelock.executeTransaction(address(timelock), 0, SIGNATURE, CALLDATA, BLOCK_TIMESTAMP + DELAY);
        assertTrue(!timelock.queuedTransactions(txHash));
        assertEq(timelock.timelockDelay(), DELAY + 1);
    }
}
