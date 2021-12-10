pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '../interfaces/ITimelock.sol';
import '../interfaces/IRaritySocietyDAOToken.sol';
import '../interfaces/IRaritySocietyDAO.sol';

contract RaritySocietyDAOStorageV1 is Initializable {

    address public daoAdmin;

    address public pendingAdmin;

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
