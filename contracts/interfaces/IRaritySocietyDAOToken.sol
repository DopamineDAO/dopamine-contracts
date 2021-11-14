pragma solidity ^0.8.9;

interface IRaritySocietyDAOToken {

    function getPriorVotes(address account, uint blockNumber) external view returns (uint32);

    function totalSupply() external view returns (uint32);

}
