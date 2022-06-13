// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../scripts/DeployDev.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Dopamine Dev Deployment Test Suite
contract DeployDevTest is Test {

    DeployDev script;

    function setUp() public virtual {
        script = new DeployDev();
    }

    function testRun() public {
        script.run();
    }


}
