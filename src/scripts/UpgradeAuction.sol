// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { DopamineAuctionHouse } from "../auction/DopamineAuctionHouse.sol";
import { DopamineAuctionHouseProxy } from "../auction/DopamineAuctionHouseProxy.sol";
import "../test/mocks/MockDopamineAuctionHouse.sol";
import "../test/mocks/MockDopamineAuctionHouseUpgraded.sol";

import { Test } from "../test/utils/test.sol";
import "../test/utils/console.sol";

contract MockContractUnpayable { }
contract MockContractPayable { receive() external payable {} }

contract UpgradeAuction is Test {

    // Contract address should be changed by staging and prod
    DopamineAuctionHouse ah = DopamineAuctionHouse(0xd4B1F099366E8C452fCDA10bAeFe3e6d6D6435DE);

    function run() public {
        vm.startBroadcast(msg.sender);
        MockDopamineAuctionHouseUpgraded upgradedImpl = new MockDopamineAuctionHouseUpgraded();

        console.log("upgradeImpl address: ", address(upgradedImpl));

        address faultyReserve = address(new MockContractUnpayable());
        address faultyDao = address(new MockContractUnpayable());

        console.log("faultyReserve: ", faultyReserve);
        console.log("faultyDao: ", faultyDao);

        bytes memory data = abi.encodeWithSelector(
            upgradedImpl.initializeV2.selector,
            faultyReserve,
            faultyDao
        );
        ah.upgradeToAndCall(address(upgradedImpl), data);
        vm.stopBroadcast();
    }
}
