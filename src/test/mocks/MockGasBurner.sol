// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

contract MockGasBurner {

    receive() external payable {
        while (gasleft() > 0) {}
    }
}
