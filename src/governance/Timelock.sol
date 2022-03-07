pragma solidity ^0.8.9;

import '../interfaces/ITimelock.sol';
import "../test/utils/console.sol";

/// @notice Function callable only by the admin.
error AdminOnly();

/// @notice Invalid set timelock delay.
error InvalidDelay();

/// @notice Signature does not match that in calldata.
error InvalidSignature();

/// @notice Function callable only by the pending owner.
error PendingAdminOnly();

/// @notice Transaction executed prematurely.
error PrematureTx();

/// @notice Transaction execution was reverted.
error RevertedTx();

/// @notice Transaction is stale.
error StaleTx();

/// @notice Function callable only by the timelock itself.
error TimelockOnly();

/// @notice Transaction is not yet queued.
error UnqueuedTx();

/// @title Timelock Contract
/// @notice Administrative time-locked execution framework for the DAO.
contract Timelock is ITimelock {

    /// @notice Extra time added to delay before a call is considered stale.
	uint256 public constant GRACE_PERIOD = 14 days;

    /// @notice Minimum and maximum times calls should be queued for.
	uint256 public constant MIN_DELAY = 2 days;
	uint256 public constant MAX_DELAY = 30 days;

    /// @notice Address responsible for administering timelock.
	address public admin;

    /// @notice Temporary address used between admin conversion.
    address public pendingAdmin;

    /// @notice Time in seconds for how long an execution should be queued for.
    uint256 public delay;

    /// @notice Mapping of transaction hashes to whether they've been queued.
    mapping (bytes32 => bool) public queuedTransactions;

    /// @notice Modifier to restrict calls to admin only.
	modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
		_;
	}

    /// @notice Create a timelock with admin `admin_` and delay `delay_`.
    /// @param admin_ Address of administrator to control the timelock.
    /// @param delay_ Time in seconds for which executions remain queued.
    /// @dev For integration with the DAO, `admin_` should be the DAO address.
    constructor(address admin_, uint256 delay_) {
        admin = admin_;
        if (delay_ < MIN_DELAY || delay_ > MAX_DELAY) {
            revert InvalidDelay();
        }
        delay = delay_;
        emit DelaySet(delay);
    }

    /// @notice Sets a new timelock delay `newDelay`.
    /// @param newDelay The new timelock delay, in seconds.
    function setDelay(uint256 newDelay) public {
        if (msg.sender != address(this)) {
            revert TimelockOnly();
        }
        if (newDelay < MIN_DELAY || newDelay > MAX_DELAY) {
            revert InvalidDelay();
        }
        delay = newDelay;
        emit DelaySet(delay);
    }

    /// @notice Sets a new pending admin `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
	function setPendingAdmin(address newPendingAdmin) public override {
        if (msg.sender != address(this)) {
            revert TimelockOnly();
        }
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

    /// @notice Queues a call for future execution.
    /// @param target Address that this call will be targeted to.
    /// @param value Eth value to send along with the call.
    /// @param signature Signature of the execution call.
    /// @param data Calldata to be passed with the call.
    /// @param eta Timestamp at which call is eligible for execution.
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin returns (bytes32) {
        if (eta < block.timestamp + delay) {
            revert PrematureTx();
        }
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /// @notice Cancels an execution call.
    /// @param target Address that this call will be targeted to.
    /// @param value Eth value to send along with the call.
    /// @param signature Signature of the execution call.
    /// @param data Calldata to be passed with the call.
    /// @param eta Timestamp at which call is eligible for execution.
    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /// @notice Executes an queued execution call.
    /// @param target Address that this call will be targeted to.
    /// @param value Eth value to send along with the call.
    /// @param signature Signature of the execution call.
    /// @param data Calldata to be passed with the call.
    /// @param eta Timestamp at which call is eligible for execution.
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        if (!queuedTransactions[txHash]) {
            revert UnqueuedTx();
        }
        if (block.timestamp < eta) {
            revert PrematureTx();
        }
        if (block.timestamp > eta + GRACE_PERIOD) {
            revert StaleTx();
        }
        queuedTransactions[txHash] = false;

        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        if (bytes4(keccak256(abi.encodePacked(signature))) != selector) {
            revert InvalidSignature();
        }
		
		(bool success, bytes memory returnData) = target.call{ value: value }(data);
        if (!success) {
            revert RevertedTx();
        }
		emit ExecuteTransaction(txHash, target, value, signature, data, eta);
		return returnData;
    }

    /// @notice receive  and fallback functions for accepting Ether.
    /// @dev The timelock will function as the DAO's treasury.
	receive() external payable {}
	fallback() external payable {}
}
