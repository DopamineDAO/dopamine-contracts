pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts/utils/Address.sol';
import './RaritySocietyDAOStorage.sol';

import { TransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

contract RaritySocietyDAOProxy is RaritySocietyDAOStorageV1, TransparentUpgradeableProxy {

    constructor(
        address impl,
        address admin,
        bytes memory data
    ) TransparentUpgradeableProxy(impl, admin, data) {}

}
