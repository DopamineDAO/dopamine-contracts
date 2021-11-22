// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns DAO auction house proxy
pragma solidity ^0.8.9;

import { TransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

contract RaritySocietyAuctionHouseProxy is TransparentUpgradeableProxy {
    constructor(
        address impl,
        address admin,
        bytes memory data
    ) TransparentUpgradeableProxy(impl, admin, data) {}
}
