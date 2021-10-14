// SPDX-License-Identifier: GPL-3.0

// @title Contract mock for an OpenSea proxy delegate.

pragma solidity ^0.8.9;

contract MockProxy {

    address private _owner;
    address internal _implementation;

    modifier onlyOwner() { 
        require(msg.sender == _owner);
        _;
    }

    constructor(address owner, address implementation) {
        _implementation = implementation;
        _owner = owner;
    }

    function upgradeTo(address implementation) public onlyOwner {
        _implementation = implementation;
    }

}
