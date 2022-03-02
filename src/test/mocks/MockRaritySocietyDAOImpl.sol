// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society DAO Mock

pragma solidity ^0.8.9;

import { RaritySocietyDAOImpl } from '../../governance/RaritySocietyDAOImpl.sol';

import "../utils/Hevm.sol";

/// @notice Signer unsupported for EIP-712 voting.
error UnsupportedSigner();

contract MockRaritySocietyDAOImpl is RaritySocietyDAOImpl {

    mapping(address => uint256) private signers;

    address constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256('hevm cheat code')))));
    Hevm constant vm = Hevm(HEVM_ADDRESS);

    string constant VOTE_REASON = "Rarity";

    constructor(
        address proxy
    ) RaritySocietyDAOImpl(proxy) {}
    
    // Mock method to save a bunch of signer keys for EIP-712 testing.
    function initSigners(uint256[2] memory pks) public {
        for (uint256 i = 0; i < pks.length; i++) {
            signers[vm.addr(pks[i])] = pks[i];

        }
    }

    // Votes using an EIP-712-signed message hash from `msg.sender`.
    function mockCastVoteBySig(uint8 support) public {
        uint256 pk = signers[msg.sender];
        if (pk == 0) {
            revert UnsupportedSigner();
        }
        bytes32 structHash = 
            keccak256(
                abi.encode(
                    VOTE_TYPEHASH,
                    msg.sender,
                    proposalId,
                    support
                )
            );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        this.castVoteBySig(msg.sender, support, v, r, s);
    }

}
