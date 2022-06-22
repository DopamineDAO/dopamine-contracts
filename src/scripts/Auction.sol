// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { DopamineAuctionHouse } from "../auction/DopamineAuctionHouse.sol";
import { DopamineAuctionHouseProxy } from "../auction/DopamineAuctionHouseProxy.sol";

import { Test } from "../test/utils/test.sol";
import "../test/utils/console.sol";

contract AuctionDev_Stag is Test {

    // Contract address should be changed by staging and prod
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

    function setPendingAdmin() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        address newPendingAdmin = 0x4ee07a0a97c03e9E52B8c47e30CDa07fC2F14709;
        ah.setPendingAdmin(newPendingAdmin);

        vm.stopBroadcast();
    }

    function acceptAdmin() public {
        vm.startBroadcast(msg.sender);
        ah.acceptAdmin();
        vm.stopBroadcast();
    }

    function setAuctionDuration() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 newAuctionDuration = 10 minutes;
        ah.setAuctionDuration(newAuctionDuration);

        vm.stopBroadcast();
    }

    function setTreasurySplit() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 newTreasurySplit = 20;
        ah.setTreasurySplit(newTreasurySplit);

        vm.stopBroadcast();
    }

    function setAuctionBuffer() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 newAuctionBuffer = 10 minutes;
        ah.setAuctionBuffer(newAuctionBuffer);

        vm.stopBroadcast();
    }

    function setReservePrice() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 newReservePrice = 1 ether;
        ah.setReservePrice(newReservePrice);

        vm.stopBroadcast();
    }
}
