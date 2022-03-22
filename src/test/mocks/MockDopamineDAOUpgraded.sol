
// SPDX-License-Identifier: GPL-3.0

/// @title The Dopamine DAO Mock

pragma solidity ^0.8.13;

import { DopamineDAO } from '../../governance/DopamineDAO.sol';

error DummyError();

contract MockDopamineDAOUpgraded is DopamineDAO {

    uint256 public newParameter;

    constructor(
        address proxy
    ) DopamineDAO(proxy) {}
    
    function initializeV2(uint256 newParameter_) public {
        newParameter = newParameter_;
    }

    function test() public pure {
        revert DummyError();
    }

}
