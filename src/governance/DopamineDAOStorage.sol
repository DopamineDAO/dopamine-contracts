// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import '../interfaces/ITimelock.sol';
import '../interfaces/IDopamineDAOToken.sol';
import '../interfaces/IDopamineDAO.sol';

contract DopamineDAOStorageV1 {

    uint32 public votingPeriod;

    uint32 public votingDelay;

    uint32 public quorumThresholdBPS;

    ITimelock public timelock;

    uint32 public proposalThreshold;

    uint32 public proposalId;

    address public vetoer;

    IDopamineDAOToken public token;

    address public admin;

    address public pendingAdmin;

    IDopamineDAO.Proposal public proposal;

    mapping(address => IDopamineDAO.Receipt) public receipts;

}
