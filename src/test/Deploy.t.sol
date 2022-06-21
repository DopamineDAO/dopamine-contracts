// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../scripts/Deploy_Stag.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Dopamine Dev Deployment Test Suite
contract DeployDevTest is Test {

    Deploy_Stag script;

    function setUp() public virtual {
        script = new Deploy_Stag();
    }

    function testRun() public {
        script.run();
    }


}
