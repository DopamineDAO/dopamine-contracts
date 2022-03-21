// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../../erc721/ERC721Votable.sol";
import "../utils/HEVM.sol";
import "../utils/console.sol";

/// @notice Signer unsupported for EIP-712 voting.
error UnsupportedSigner();

contract MockERC721Votable is ERC721Votable {

    uint256 EXPIRY = 10**9;

    string public constant NAME = 'Rarity Society';
    string public constant SYMBOL = 'RARITY';

    mapping(address => uint256) private signers;

    address constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256('hevm cheat code')))));
    Hevm constant vm = Hevm(HEVM_ADDRESS);

    constructor(uint256 maxSupply_)
        ERC721Votable(NAME, SYMBOL, maxSupply_) {}

    // Mock method to save a bunch of signer keys for EIP-712 testing.
    function initSigners(uint256[3] memory pks) public {
        for (uint256 i = 0; i < pks.length; i++) {
            signers[vm.addr(pks[i])] = pks[i];

        }
    }

    function mint(address to, uint256 id) public virtual {
            _mint(to, id);
        }

    function burn(uint256 id) public virtual {
            _burn(id);
    }

    // Delegates using an EIP-712-signed message hash from `msg.sender`.
    function mockDelegateBySig(address delegatee) public {
        uint256 pk = signers[msg.sender];
        if (pk == 0) {
            revert UnsupportedSigner();
        }
        uint256 nonce = nonces[msg.sender];
        bytes32 structHash = 
            keccak256(
                abi.encode(
                    DELEGATION_TYPEHASH,
                    msg.sender,
                    delegatee,
                    nonce,
                    EXPIRY
                )
            );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        this.delegateBySig(msg.sender, delegatee, EXPIRY, v, r, s);
    }

    // Reset token, checkpoint, and delegate state for testing.
    function reset(address[3] memory voters) public {
        for (uint256 i = 0; i < totalSupply; i++) {
            burn(i);
        }
        for (uint256 i = 0; i < voters.length; i++) {
            delete nonces[voters[i]];
            delete checkpoints[voters[i]];
            _delegates[voters[i]] = address(0);
        }
    }

}
