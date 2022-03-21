// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// This file is under the copyright license: Copyright 2020 Compound Labs, Inc.
/// 
/// Timelock.sol is a modification of Nouns DAO's NounsDAOExecutor.sol:
/// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/governance/NounsDAOExecutor.sol
///
/// Copyright licensing is under the BSD-3-Clause license, as the above contract
/// is a rework of Compound Lab's Timelock.sol (3-Clause BSD Licensed).
/// 
/// The following major changes were made from the original Nouns DAO contract:
/// - `executeTransaction` was changed to only accept calls with the `data`
///   parameter defined as the abi-encoded function calldata with the function 
///   selector included. This differs from the Nouns DAO variant which accepted
///   either the above or `data` as only the abi-encoded function parameters.
/// - An explicit check was added to ensure that the abi-encoded signature in
///   `executeTransaction` matches the function selector provded in calldata.
 
import '../errors.sol';
import {ITimelock} from "../interfaces/ITimelock.sol";

/// @title Timelock Contract & Dopamine DAO Treasury
/// @notice The timelock is an administrative contract responsible for ensuring
///  passed proposals from the DAO have their execution calls succesfully queued
///  with enough time to marinade before execution in case of any issues.
contract Timelock is ITimelock {

    /// @notice Extra time in seconds added to delay before call becomes stale.
	uint256 public constant GRACE_PERIOD = 14 days;

    /// @notice Minimum settable timelock delay, in seconds.
	uint256 public constant MIN_TIMELOCK_DELAY = 2 days;

    /// @notice Maximum settable timelock delay, in seconds.
	uint256 public constant MAX_TIMELOCK_DELAY = 30 days;

    /// @notice The address responsible for configuring the timelock.
	address public admin;

    /// @notice Address of temporary admin that will become admin once accepted.
    address public pendingAdmin;

    /// @notice Time in seconds for how long a call must be queued for.
    uint256 public timelockDelay;

    /// @notice Mapping of execution call hashes to whether they've been queued.
    mapping (bytes32 => bool) public queuedTransactions;

    /// @notice Modifier to restrict calls to admin only.
	modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
		_;
	}

    /// @notice Instantiates the timelock contract.
    /// @param admin_ Address of the admin, who controls the timelock.
    /// @param timelockDelay_ Time in seconds for which executions remain queued.
    /// @dev For integration with the DAO, `admin_` should be the DAO address.
    constructor(address admin_, uint256 timelockDelay_) {
        admin = admin_;
        if (
            timelockDelay_ < MIN_TIMELOCK_DELAY || 
            timelockDelay_ > MAX_TIMELOCK_DELAY
        ) 
        {
            revert TimelockDelayInvalid();
        }
        timelockDelay = timelockDelay_;
        emit TimelockDelaySet(timelockDelay);
    }

    /// @notice Allows timelock to receive Ether on calls with empty calldata.
	receive() external payable {}

    /// @notice Allows timelock to receive Ether through the fallback mechanism.
	fallback() external payable {}

    /// @inheritdoc ITimelock
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin returns (bytes32) {
        if (eta < block.timestamp + timelockDelay) {
            revert TransactionPremature();
        }
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit TransactionQueued(txHash, target, value, signature, data, eta);
        return txHash;
    }
    
    /// @inheritdoc ITimelock
    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit TransactionCanceled(txHash, target, value, signature, data, eta);
    }

    /// @inheritdoc ITimelock
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        if (!queuedTransactions[txHash]) {
            revert TransactionNotYetQueued();
        }
        if (block.timestamp < eta) {
            revert TransactionPremature();
        }
        if (block.timestamp > eta + GRACE_PERIOD) {
            revert TransactionStale();
        }
        queuedTransactions[txHash] = false;

        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        if (bytes4(keccak256(abi.encodePacked(signature))) != selector) {
            revert SignatureInvalid();
        }
		
		(bool ok, bytes memory returnData) = target.call{ value: value }(data);
        if (!ok) {
            revert TransactionReverted();
        }
		emit TransactionExecuted(txHash, target, value, signature, data, eta);
		return returnData;
    }

    /// @inheritdoc ITimelock
    function setTimelockDelay(uint256 newTimelockDelay) public {
        if (msg.sender != address(this)) {
            revert TimelockOnly();
        }
        if (
            newTimelockDelay < MIN_TIMELOCK_DELAY || 
            newTimelockDelay > MAX_TIMELOCK_DELAY
        ) 
        {
            revert TimelockDelayInvalid();
        }
        timelockDelay = newTimelockDelay;
        emit TimelockDelaySet(timelockDelay);
    }

    /// @inheritdoc ITimelock
	function setPendingAdmin(address newPendingAdmin) public override {
        if (msg.sender != address(this)) {
            revert TimelockOnly();
        }
		pendingAdmin = newPendingAdmin;
		emit PendingAdminSet(pendingAdmin);
	}

    /// @inheritdoc ITimelock
	function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

		emit AdminChanged(admin, pendingAdmin);
		admin = pendingAdmin;
        pendingAdmin = address(0);
	}


}
