// SPDX-License-Identifier: MIT
//
//
// This is a contract mock of RaritySocietyDAOImpl that self-assigns
// administrative privileges to enable unit-testing without a proxy contract

pragma solidity ^0.8.9;

import "../governance/RaritySocietyDAOImpl.sol";

contract MockRaritySocietyDAOImpl is RaritySocietyDAOImpl {
    
	constructor(
		address timelock_,
		address token_,
		address vetoer_,
        address admin_,
		uint256 votingPeriod_,
		uint256 votingDelay_,
		uint256 proposalThreshold_,
		uint256 quorumVotesBPS_
	) {
        initialize(admin_, timelock_, token_, vetoer_, votingPeriod_, votingDelay_, proposalThreshold_, quorumVotesBPS_);

    }
}
