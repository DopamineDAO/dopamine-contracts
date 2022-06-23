// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IDopamineAuctionHouse } from "../../interfaces/IDopamineAuctionHouse.sol";
import { MockDopamineAuctionHouseUpgradedStorage } from './MockDopamineAuctionHouseUpgradedStorage.sol';
import { MockDopamineAuctionHouse } from './MockDopamineAuctionHouse.sol';

/// @title Mock upgraded auction house contract.
contract MockDopamineAuctionHouseUpgraded is MockDopamineAuctionHouse, MockDopamineAuctionHouseUpgradedStorage {

    function initializeV2(address payable newReserve, address payable newTreasury) public {
        reserve = newReserve;
        treasury = newTreasury;
        reserve2 = payable(address(this));
        treasury2 = payable(address(this));
    }

    function setReserve2(address payable newReserve) public {
        reserve = newReserve;
    }

    function setTreasury2(address payable newTreasury) public {
        treasury = newTreasury;
    }

    function withdraw() public {
        (bool success, ) = treasury.call{ value: address(this).balance, gas: 30_000 }(new bytes(0));
        if (!success) {
            revert();
        }
    }

}

