// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { MockDopamineAuctionHouse } from './MockDopamineAuctionHouse.sol';

/// @title Mock upgraded auction house contract.
contract MockDopamineAuctionHouseUpgraded is MockDopamineAuctionHouse {

    function initializeV2(address payable newReserve, address payable newTreasury) public {
        reserve = newReserve;
        treasury = newTreasury;
    }

    function setReserve(address payable newReserve) public onlyAdmin {
        reserve = newReserve;
    }

    function setTreasury(address payable newTreasury) public onlyAdmin {
        treasury = newTreasury;
    }

    function withdraw() public onlyAdmin {
        (bool success, ) = treasury.call{ value: address(this).balance, gas: 30_000 }(new bytes(0));
        if (!success) {
            revert();
        }
    }

}
