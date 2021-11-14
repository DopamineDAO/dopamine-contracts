pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/Address.sol';
import './RaritySocietyDAOStorage.sol';

contract RaritySocietyDAOProxy is RaritySocietyDAOProxyStorage {

     event NewImpl(address oldImplementation, address newImplementation);

	constructor(
		address timelock_,
		address token_,
		address vetoer_,
		address admin_,
		address impl_,
		uint256 votingPeriod_,
		uint256 votingDelay_,
		uint256 proposalThreshold_,
		uint256 quorumVotesBPS_
	){
		admin = msg.sender;

		delegateTo(impl_, abi.encodeWithSignature("initialize(address,address,address,uint256,uint256,uint256,uint256)",
			timelock_,
			token_,
			vetoer_,
			votingPeriod_,
			votingDelay_,
			proposalThreshold_,
			quorumVotesBPS_
		));
		
		setImpl(impl_);

		admin = admin_;
	}

	function setImpl(address impl_) public {
		require(msg.sender == admin, "setImpl may only be called by admin");
		require(Address.isContract(impl_), "implementation is not a contract");

		address oldImpl = impl;
		impl = impl_;

		emit NewImpl(oldImpl, impl);
	}

	function delegateTo(address callee, bytes memory data) internal {
		(bool success, bytes memory returnData) = callee.delegatecall(data);
		assembly {
			if eq(success, 0) {
				revert(add(returnData, 0x20), returndatasize())
			}
		}
	}

	function _fallback() internal {
		(bool success, ) = impl.delegatecall(msg.data);
		assembly {
			let m := mload(0x40)
			returndatacopy(m, 0, returndatasize())

			switch success
			case 0 { revert(m, returndatasize()) }
			default { return(m, returndatasize()) }
		}
	}

	fallback() external payable {
		_fallback();
	}

	receive() external payable {
		_fallback();
	}
}

