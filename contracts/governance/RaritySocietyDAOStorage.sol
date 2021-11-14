pragma solidity ^0.8.9;

import '../interfaces/ITimelock.sol';
import '../interfaces/IRaritySocietyDAOToken.sol';
import '../interfaces/IRaritySocietyDAO.sol';

contract RaritySocietyDAOProxyStorage {

    address public admin;
    address public pendingAdmin;
    address public impl;
}

contract RaritySocietyDAOStorageV1 is RaritySocietyDAOProxyStorage {

    address public vetoer;

    uint256 public votingPeriod;

    uint256 public votingDelay;

    uint256 public proposalThreshold;

    uint256 public quorumVotesBPS;

    uint256 public proposalCount;

    ITimelock public timelock;

    IRaritySocietyDAOToken public token;

    mapping(uint256 => IRaritySocietyDAO.Proposal) public proposals;

    mapping(address => uint256) public latestProposalIds;

}
