// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///				 ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////
 
import "./ITimelockEvents.sol";

/// @title Timelock Interface
interface ITimelock is ITimelockEvents {

    /// @notice Queues a call for future execution.
    /// @dev This function is only callable by admin, and throws if `eta` is not 
    ///  a timestamp past the current block time plus the timelock delay.
    /// @param target    The address that this call will be targeted to.
    /// @param value     The eth value in wei to send along with the call.
    /// @param signature The signature of the execution call.
    /// @param data      The calldata to be passed with the call.
    /// @param eta       The timestamp at which call is eligible for execution.
    /// @return A bytes32 keccak-256 hash of the abi-encoded parameters.
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    /// @notice Cancels an execution call.
    /// @param target    The address that this call was intended for.
    /// @param value     The eth value in wei that was to be sent with the call.
    /// @param signature The signature of the execution call.
    /// @param data      The calldata originally included with the call.
    /// @param eta       The timestamp at which call was eligible for execution.
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    /// @notice Executes a queued execution call.
    /// @dev The calldata `data` will be verified by ensuring that the passed in
    ///  signature `signaure` matches the function selector included in `data`.
    /// @param target    The address that this call was intended for.
    /// @param value     The eth value in wei that was to be sent with the call.
    /// @param signature The signature of the execution call.
    /// @param data      The calldata originally included with the call.
    /// @param eta       The timestamp at which call was eligible for execution.
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes memory);

    /// @notice Returns the grace period, in seconds, representing the time
    ///  added to the timelock delay before a transaction call becomes stale.
    function GRACE_PERIOD() external view returns (uint256);

    /// @notice Returns the timelock delay, in seconds, representing how long
    ///  call must be queued for before being eligible for execution.
    function timelockDelay() external view returns (uint256);

    /// @notice Retrieves a boolean indicating whether a transaction was queued.
    /// @param txHash Bytes32 keccak-256 hash of Abi-encoded call parameters.
    /// @return True if the transaction has been queued, false otherwise.
    function queuedTransactions(bytes32 txHash) external view returns (bool);

    /// @notice Sets the timelock delay to `newTimelockDelay`.
    /// @dev This function is only callable by the admin, and throws if the 
    ///  timelock delay is too low or too high.
    /// @param newTimelockDelay The new timelock delay to set, in seconds.
    function setTimelockDelay(uint256 newTimelockDelay) external;

    /// @notice Sets the pending admin address to  `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
    function setPendingAdmin(address newPendingAdmin) external;

    /// @notice Assigns the `pendingAdmin` address to the `admin` address.
    /// @dev This function is only callable by the pending admin.
    function acceptAdmin() external;

}
