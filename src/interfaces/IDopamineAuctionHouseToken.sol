pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IDopamineAuctionHouseToken is IERC721 {

    function mint() external returns (uint256);

}
