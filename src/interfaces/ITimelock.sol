pragma solidity ^0.8.9;
interface ITimelock {
    event NewAdmin(address oldAdmin, address newAdmin);

    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
	event NewDelay(uint256 oldDelay, uint256 newDelay);

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
