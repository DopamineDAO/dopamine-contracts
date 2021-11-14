pragma solidity ^0.8.9;

import '../interfaces/ITimelock.sol';

contract Timelock is ITimelock {

	uint256 public constant GRACE_PERIOD = 14 days;
	uint256 public constant MINIMUM_DELAY = 2 days;
	uint256 public constant MAXIMUM_DELAY = 30 days;

	address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping (bytes32 => bool) public queuedTransactions;

	modifier onlyAdmin() {
		require(msg.sender == admin, "admin only");
		_;
	}

    constructor(address admin_, uint256 delay_) {
        require(delay_ >= MINIMUM_DELAY, 'Delay exceeds min delay');
        require(delay_ <= MAXIMUM_DELAY, 'Delay exceeds max delay');
        admin = admin_;
        delay = delay_;
    }

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), 'Call must come from Timelock');
        require(delay_ >= MINIMUM_DELAY, 'Delay exceeds min delay');
        require(delay_ <= MAXIMUM_DELAY, 'Delay exceeds max delay');

        uint256 oldDelay = delay;
        delay = delay_;

        emit NewDelay(oldDelay, delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Call must come from pending admin");
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        admin = pendingAdmin;
        pendingAdmin = address(0);

		emit NewAdmin(oldAdmin, admin);
		emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "must call from timelock");
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, 'execution block must satisfy delay');

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "not yet queued");
        require(
            block.timestamp >= eta,
            "not yet passed timelock."
        );
        require(
            block.timestamp <= eta + GRACE_PERIOD,
            'tx is stale'
        );
        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
		}
		
		(bool success, bytes memory returnData) = target.call{ value: value }(callData);
		require(success, 'tx execution reverted');

		emit ExecuteTransaction(txHash, target, value, signature, data, eta);
		return returnData;

    }

	receive() external payable {}

	fallback() external payable {}
}
