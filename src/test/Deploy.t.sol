// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../scripts/DeployTabAndAuction.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Dopamine Dev Deployment Test Suite
contract DeployDevTest is Test {

    Deploy script;

    function setUp() public virtual {
        script = new Deploy();
    }

    function testRun() public {
        script.runDev();
    }


}
