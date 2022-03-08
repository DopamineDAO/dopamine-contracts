// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

interface ITimelockEvents {

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

}
