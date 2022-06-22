// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { DopamineTab } from "../nft/DopamineTab.sol";

import { Test } from "../test/utils/test.sol";
import "../test/utils/console.sol";

contract CreateDropDev_Stag is Test {
    uint256 constant FIRST_DROP_SIZE = 1;
    uint256 constant FIRST_ALLOWLIST_SIZE = 0;
    bytes32 constant FIRST_PROVENANCE_HASH = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;

    uint256 constant SECOND_DROP_SIZE = 99;
    uint256 constant SECOND_ALLOWLIST_SIZE = 8;
    bytes32 constant SECOND_PROVENANCE_HASH = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;

    uint256 constant THIRD_DROP_SIZE = 10;
    uint256 constant THIRD_ALLOWLIST_SIZE = 3;
    bytes32 constant THIRD_PROVENANCE_HASH = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;

    // Contract address should be changed by staging and prod
    DopamineTab tab = DopamineTab(0x4ee07a0a97c03e9E52B8c47e30CDa07fC2F14709);

    function run() public {
    }

    function createFirstDrop() public {
        vm.startBroadcast(msg.sender);

        tab.createDrop(
            0,  // dropId
            0,  // startIndex
            FIRST_DROP_SIZE,
            FIRST_PROVENANCE_HASH,
            FIRST_ALLOWLIST_SIZE,
            bytes32(0)
        );

        vm.stopBroadcast();
    }

    function createSecondDrop() public {
        vm.startBroadcast(msg.sender);

        uint256 startIndex = FIRST_DROP_SIZE;

        tab.createDrop(
            1,  // dropId
            startIndex,  // startIndex
            SECOND_DROP_SIZE,
            SECOND_PROVENANCE_HASH,
            SECOND_ALLOWLIST_SIZE,
            bytes32(0)
        );

        vm.stopBroadcast();
    }

    function createThirdDrop() public {
        vm.startBroadcast(msg.sender);

        uint256 startIndex = FIRST_DROP_SIZE + SECOND_DROP_SIZE;

        tab.createDrop(
            2,  // dropId
            startIndex,  // startIndex
            THIRD_DROP_SIZE,
            THIRD_PROVENANCE_HASH,
            THIRD_ALLOWLIST_SIZE,
            bytes32(0)
        );

        vm.stopBroadcast();
    }

    function setMinter() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        address newMinter = 0x4ee07a0a97c03e9E52B8c47e30CDa07fC2F14709;
        tab.setMinter(newMinter);

        vm.stopBroadcast();
    }

    function setPendingAdmin() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        address newPendingAdmin = 0x4ee07a0a97c03e9E52B8c47e30CDa07fC2F14709;
        tab.setPendingAdmin(newPendingAdmin);

        vm.stopBroadcast();
    }

    function acceptAdmin() public {
        vm.startBroadcast(msg.sender);
        tab.acceptAdmin();
        vm.stopBroadcast();
    }

    function setDropURI() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 id = 0;
        string memory uri = "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/";
        tab.setDropURI(id, uri);

        vm.stopBroadcast();
    }

    function updateDrop() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 id = 0;
        bytes32 provenanceHash = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;
        bytes32 allowlist = bytes32(0);
        tab.updateDrop(id, provenanceHash, allowlist);

        vm.stopBroadcast();
    }

    function setBaseURI() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        string memory uri = "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/";
        tab.setBaseURI(uri);

        vm.stopBroadcast();
    }

    function setDropDelay() public {
        vm.startBroadcast(msg.sender);

        // Configured before run
        uint256 newDropDelay = 10 minutes;
        tab.setDropDelay(newDropDelay);

        vm.stopBroadcast();
    }
}
