// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { DopamineAuctionHouse } from "../auction/DopamineAuctionHouse.sol";
import { DopamineAuctionHouseProxy } from "../auction/DopamineAuctionHouseProxy.sol";
import { DopamineDAO } from "../governance/DopamineDAO.sol";
import { DopamineDAOProxy } from "../governance/DopamineDAOProxy.sol";
import { DopamineTab } from "../nft/DopamineTab.sol";
import { Timelock } from "../governance/Timelock.sol";

import { Test } from "../test/utils/test.sol";
import "../test/utils/console.sol";

contract DeployDev is Test {

    // Contracts
    DopamineAuctionHouse ah;
    DopamineAuctionHouse ahImpl;
    DopamineAuctionHouseProxy ahProxy;
    DopamineDAO dao;
    DopamineDAO daoImpl;
    DopamineDAOProxy daoProxy;
    Timelock timelock;
    DopamineTab tab;

    function run() public {

        vm.startBroadcast(msg.sender);

        uint8 nonce = uint8(vm.getNonce(msg.sender));
        address ahAddress = getContractAddress(msg.sender, bytes1(nonce + 0x02));
        address daoAddress = getContractAddress(msg.sender, bytes1(nonce + 0x05));

        // 1. Deploy the Dopamine Tab.
        tab = new DopamineTab(
            "https://dev-api.dopamine.xyz/metadata/",
            ahAddress,
            address(0x1E525EEAF261cA41b809884CBDE9DD9E1619573A), // Rinkeby OS
            10 minutes, // Min wait of 10 min (MAKE SURE TO CHANGE CONTRACT)
            9           // 9 max supply
        );

        // 2. Deploy the auction house implementation contract.
        ahImpl = new DopamineAuctionHouse();

        // 3. Deploy the auction house proxy contract.
        ahProxy = new DopamineAuctionHouseProxy(
            address(ahImpl),
            abi.encodeWithSelector(
                ahImpl.initialize.selector,
                address(tab),
                daoAddress,
                msg.sender,
                100,             // 100% revenue
                10 minutes,      // 10-min auction buffer
                1 wei,           // ~0 reserve price
                12 hours         // 12-hour auction duration
            )
        );
        assertEq(address(ahProxy), ahAddress);
        ah = DopamineAuctionHouse(ahAddress);

        vm.stopBroadcast();
    }

}
