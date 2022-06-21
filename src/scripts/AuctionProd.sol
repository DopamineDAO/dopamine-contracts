// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { DopamineAuctionHouse } from "../auction/DopamineAuctionHouse.sol";
import { DopamineAuctionHouseProxy } from "../auction/DopamineAuctionHouseProxy.sol";

import { Test } from "../test/utils/test.sol";
import "../test/utils/console.sol";

contract AuctionDev_Stag is Test {

    // Contracts
    DopamineAuctionHouse ah = DopamineAuctionHouse(0x798378c914C50531a5878cADA442932148804048);

    function run() public {
    }

    function resumeNewAuctions() public {
        vm.startBroadcast(msg.sender);
        ah.resumeNewAuctions();
        vm.stopBroadcast();
    }

    function suspendNewAuctions() public {
        vm.startBroadcast(msg.sender);
        ah.suspendNewAuctions();
        vm.stopBroadcast();
    }

    function settleAuction() public {
        vm.startBroadcast(msg.sender);
        ah.settleAuction();
        vm.stopBroadcast();
    }
}
