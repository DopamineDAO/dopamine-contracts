
// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society DAO Mock

pragma solidity ^0.8.9;

import { RaritySocietyDAOImpl } from '../../governance/RaritySocietyDAOImpl.sol';

import "../utils/Hevm.sol";

error DummyError();

contract MockRaritySocietyDAOUpgraded is RaritySocietyDAOImpl {

    uint256 public newParameter;

    constructor(
        address proxy
    ) RaritySocietyDAOImpl(proxy) {}
    
    function initializeV2(uint256 newParameter_) public {
        newParameter = newParameter_;
    }

    function test() public {
        revert DummyError();
    }

}
