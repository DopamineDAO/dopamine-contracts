// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { MockDopamineAuctionHouse } from './MockDopamineAuctionHouse.sol';

/// @title Mock upgraded auction house contract.
contract MockDopamineAuctionHouseUpgraded is MockDopamineAuctionHouse {

    function initializeV2(address payable newReserve, address payable newDAO) public {
        reserve = newReserve;
        dao = newDAO;
    }

    function setReserve(address payable newReserve) public onlyAdmin {
        reserve = newReserve;
    }

    function setDAO(address payable newDAO) public onlyAdmin {
        dao = newDAO;
    }

    function withdraw() public onlyAdmin {
        (bool success, ) = dao.call{ value: address(this).balance, gas: 30_000 }(new bytes(0));
        if (!success) {
            revert();
        }
    }

}
