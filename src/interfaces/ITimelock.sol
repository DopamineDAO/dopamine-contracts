// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./ITimelockEvents.sol";

interface ITimelock is ITimelockEvents {

    function setPendingAdmin(address pendingAdmin) external;

    function setDelay(uint256 delay) external;

    function delay() external view returns (uint256);

    function acceptAdmin() external;

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes memory);

    function queuedTransactions(bytes32 hash) external view returns (bool);
	function GRACE_PERIOD() external view returns (uint256);
}
