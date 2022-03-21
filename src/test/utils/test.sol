// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "./console.sol";
import "./Hevm.sol";


/// @title Extended testing framework
contract Test is DSTest {

    error ArrayMismatch();

    Hevm constant vm = Hevm(HEVM_ADDRESS);

    function expectRevert(string memory error) internal virtual {
        return vm.expectRevert(abi.encodeWithSignature(error));
    }

    function assertEq(uint256[] memory  a, uint256[] memory b) internal {
        if (a.length != b.length) {
            revert ArrayMismatch();
        }
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                emit log("Error: a == b not satisfied [uint256[]]");
                fail();
            }
        }
    }

    function assertEq(bytes[] memory  a, bytes[] memory b) internal {
        if (a.length != b.length) {
            revert ArrayMismatch();
        }
        for (uint256 i = 0; i < a.length; i++) {
            assertEq0(a[i], b[i]);
        }
    }

    function assertEq(string[] memory a, string[] memory b) internal {
        if (a.length != b.length) {
            revert ArrayMismatch();
        }
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(address[] memory a, address[] memory b) internal {
        if (a.length != b.length) {
            revert ArrayMismatch();
        }
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function getContractAddress(address sender, bytes1 nonce) internal view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xd6), bytes1(0x94), sender, nonce)
        );
        return address(uint160(uint256(hash)));
    }

    function EIP712Hash(string memory domainName, bytes32 structHash, address verifyingContract) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Dopamine DAO")),
                keccak256(bytes("1")),
                block.chainid,
                verifyingContract
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function logStringArr(string[] memory arr) public {
        for (uint256 i = 0; i < arr.length; i++) {
            console.logString(arr[i]);
        }
    }

}
