import "./RaritySocietyDAOImpl.t.sol";

import "./mocks/MockRaritySocietyDAOUpgraded.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RaritySocietyDAOProxyTest is RaritySocietyDAOTest {
    function setUp() public override {
        super.setUp();

        address proxyAddr = getContractAddress(address(ADMIN), 0x03); // DAO proxy address (nonce = 3)

        MockRaritySocietyDAOImpl daoImpl = new MockRaritySocietyDAOImpl(proxyAddr);
        timelock = new Timelock(
            proxyAddr,
            TIMELOCK_DELAY
        );
        TARGETS[0] = address(timelock);
        bytes memory data = abi.encodeWithSelector(
            daoImpl.initialize.selector,
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );
		ERC1967Proxy proxy = new ERC1967Proxy(address(daoImpl), data);
        dao = MockRaritySocietyDAOImpl(address(proxy));
    }

    function testUpgrade() proposalCreated public {
        MockRaritySocietyDAOUpgraded upgradedImpl = new MockRaritySocietyDAOUpgraded(address(dao));
        
        // New upgrade mechanics should not work before upgrade.
        MockRaritySocietyDAOUpgraded daoUpgraded = MockRaritySocietyDAOUpgraded(address(dao));
        vm.expectRevert(new bytes(0));
        daoUpgraded.newParameter();
        vm.expectRevert(new bytes(0));
        daoUpgraded.test();

        // Upgrades should not work if called by unauthorized upgrader.
        vm.startPrank(FROM);
        expectRevert("UnauthorizedUpgrade()");
        dao.upgradeTo(address(upgradedImpl));

        // On upgrade, mechanics should work.
        vm.startPrank(ADMIN);
        dao.upgradeTo(address(upgradedImpl));
        assertEq(daoUpgraded.newParameter(), 0);
        assertEq(daoUpgraded.proposalId(), 1);
        expectRevert("DummyError()");
        daoUpgraded.test();

        // Upgrades should also work with function calls.
        MockRaritySocietyDAOUpgraded upgradedImplv2 = new MockRaritySocietyDAOUpgraded(address(dao));
        bytes memory data = abi.encodeWithSelector(
            upgradedImplv2.initializeV2.selector,
            9000
        );
        daoUpgraded.upgradeToAndCall(address(upgradedImplv2), data);
        assertEq(daoUpgraded.newParameter(), 9000);
    }
}
