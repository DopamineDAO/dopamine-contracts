// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

interface IDopamineDAOToken {

    function getPriorVotes(address account, uint blockNumber) external view returns (uint32);

    function totalSupply() external view returns (uint256);

}
