// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////
 
/// @title Timelock Events Interface
interface ITimelockEvents {

    /// @notice Emits when a new transaction execution call is queued.
    /// @param txHash    Sha-256 hash of abi-encoded execution call parameters.
    /// @param target    Target addresses of the call to be queued.
    /// @param value     Amount (in wei) to send with the queued transaction.
    /// @param signature The function signature of the queued transaction.
    /// @param data      Calldata to be tabed with the queued transaction call.
    /// @param eta       Timestamp at which call is eligible for execution. 
	event TransactionQueued(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);

    /// @notice Emits when a new transaction execution call is canceled.
    /// @param txHash    Sha-256 hash of abi-encoded execution call parameters.
    /// @param target    Target addresses of the canceled call.
    /// @param value     Amount (in wei) that was supposed to be sent with call.
    /// @param signature The function signature of the canceled transaction.
    /// @param data      Calldata that was supposed to be sent with the call.
    /// @param eta       Timestamp at which call was eligible for execution. 
	event TransactionCanceled(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);

    /// @notice Emits when a new transaction execution call is executed.
    /// @param txHash    Sha-256 hash of abi-encoded execution call parameters.
    /// @param target    Target addresses of the executed call.
    /// @param value     Amount (in wei) that was sent with the transaction.
    /// @param signature The function signature of the executed transaction.
    /// @param data      Calldata that was tabed to the executed transaction.
    /// @param eta       Timestamp at which call became eligible for execution. 
	event TransactionExecuted(
		bytes32 indexed txHash,
		address indexed target,
		uint256 value,
		string signature,
		bytes data,
		uint256 eta
	);

    /// @notice Emits when admin is changed from `oldAdmin` to `newAdmin`.
    /// @param oldAdmin The address of the previous admin.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address oldAdmin, address newAdmin);

    /// @notice Emits when a new pending admin `pendingAdmin` is set.
    /// @param pendingAdmin The address of the pending admin set.
    event PendingAdminSet(address pendingAdmin);

    /// @notice Emits when a new timelock delay `timelockDelay` is set.
    /// @param timelockDelay The new timelock delay to set, in blocks.
	event TimelockDelaySet(uint256 timelockDelay);

}
