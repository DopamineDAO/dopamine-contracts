// SPDX-License-Identifier: GPL-3.0

// @title Contract mock for OpenSea's Proxy Registry.

pragma solidity ^0.8.13;

import { IOpenSeaProxyRegistry } from '../../interfaces/IOpenSeaProxyRegistry.sol';
import { MockProxy } from './MockProxy.sol';

contract MockProxyRegistry is IOpenSeaProxyRegistry {

    address public proxyImplementation;

    mapping(address => address) public proxies;

    function registerProxy() public returns (MockProxy proxy) {
        require(proxies[msg.sender] == address(0));
        proxy = new MockProxy(msg.sender, proxyImplementation);
        proxies[msg.sender] = address(proxy);
        return proxy;
    }
}
