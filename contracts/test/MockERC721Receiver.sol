// SPDX-License-Identifier: GPL-3.0

// @title Contract mock ERC721 receiver.

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

contract MockERC721Receiver is IERC721Receiver {

    bytes4 private immutable _retval;
    bool private immutable _throws;

    event ERC721Received(address operator, address from, uint256 tokenId, bytes data);

    constructor(bytes4 retval, bool throws) {
        _retval = retval;
        _throws = throws;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public override returns (bytes4) {
        if (_throws) {
            revert("MockERC721Receiver: throwing");
        }
        emit ERC721Received(operator, from, tokenId, data);
        return _retval;
    }
}
