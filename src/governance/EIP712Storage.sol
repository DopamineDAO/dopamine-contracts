pragma solidity ^0.8.9;

contract EIP712Storage {

    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    constructor() {
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("Rarity Society DAO")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

}
