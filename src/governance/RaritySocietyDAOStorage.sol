pragma solidity ^0.8.9;

import '../interfaces/ITimelock.sol';
import '../interfaces/IRaritySocietyDAOToken.sol';
import '../interfaces/IRaritySocietyDAO.sol';
import './EIP712Storage.sol';

contract RaritySocietyDAOStorageV1 is EIP712Storage {

    uint32 public votingPeriod;

    uint32 public votingDelay;

    uint32 public quorumThresholdBPS;

    ITimelock public timelock;

    uint32 public proposalThreshold;

    uint32 public proposalId;

    address public vetoer;

    IRaritySocietyDAOToken public token;

    address public admin;

    address public pendingAdmin;

    IRaritySocietyDAO.Proposal public proposal;

    mapping(address => IRaritySocietyDAO.Receipt) public receipts;


}
