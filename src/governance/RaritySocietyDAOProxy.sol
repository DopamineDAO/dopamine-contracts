pragma solidity ^0.8.9;

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import './EIP712Storage.sol';

contract RaritySocietyDAOProxy is ERC1967Proxy, EIP712Storage {

    constructor(
        address impl,
        bytes memory data
    ) ERC1967Proxy(impl, data) {
    }

}
