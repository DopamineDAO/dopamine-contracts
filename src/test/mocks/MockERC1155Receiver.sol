// SPDX-License-Identifier: GPL-3.0

// @title Contract mock ERC1155 receiver.

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

contract MockERC1155Receiver is IERC1155Receiver {

    error MockERC1155ReceiverError();

    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC1155_RECEIVER_INTERFACE_ID = 0x4e2312e0;

    bytes4 private immutable _retval;
    bool private immutable _throws;

    event ERC1155Received(address operator, address from, uint256 id, uint256 value, bytes data);
    event ERC1155BatchReceived(address operator, address from, uint256[] ids, uint256[] values, bytes data);

    constructor(bytes4 retval, bool throws) {
        _retval = retval;
        _throws = throws;
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == _ERC165_INTERFACE_ID ||
            interfaceId == _ERC1155_RECEIVER_INTERFACE_ID;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public override returns (bytes4) {
        if (_throws) {
            revert MockERC1155ReceiverError();
        }
        emit ERC1155Received(operator, from, id, value, data);
        return _retval;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) public override returns (bytes4) {
        if (_throws) {
            revert MockERC1155ReceiverError();
        }
        emit ERC1155BatchReceived(operator, from, ids, values, data);
        return _retval;
    }
}
