// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../interfaces/IDopamintPass.sol";
import "../DopamintPass.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Dopamint Pass Test Suites
contract DopamintPassTest is Test, IDopamintPassEvents {

    uint256 constant NFT = 0;
    uint256 constant NFT_1 = 1;

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    address constant W1 = address(2);
    address constant W2 = address(22);
    address constant W3 = address(66);
    address constant W4 = address(126);
    address constant W5 = address(215);
    address constant W6 = address(356);
    address constant W7 = address(457);
    address constant W8 = address(638);
    address constant W9 = address(703);
    address constant W10 = address(763);

    /// @notice Whitelisted addresses (index = token received).
    address[10] WHITELISTED = [W1, W2, W3, W4, W5, W6, W7, W8, W9, W10];
    string[] proofInputs;
    uint256 constant CLAIM_SLOT = 4;

    /// @notice Addresses used for testing.
    address constant OWNER = address(1337);
    address constant FROM = address(99);
    address constant TO = address(69);
    address constant OPERATOR = address(420);

    address constant PROXY_REGISTRY = address(12629);

    DopamintPass token;

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(OWNER);

        token = new DopamintPass(OWNER, IProxyRegistry(PROXY_REGISTRY));

        addressToString(W1, 0);
        
        // 3 inputs for CLI args
        string[] memory inputs = new string[](3 + WHITELISTED.length);
        inputs[0] = "npx";
        inputs[1] = "hardhat";
        inputs[2] = "merkle";

        // 5 inputs for CLI args
        proofInputs = new string[](5 + WHITELISTED.length);
        proofInputs[0] = "npx";
        proofInputs[1] = "hardhat";
        proofInputs[2] = "merkleproof";
        proofInputs[3] = "--input";

        for (uint256 i = 0; i < WHITELISTED.length; i++) {
            string memory whitelisted = addressToString(WHITELISTED[i], i);
            inputs[i + 3] = whitelisted;
            proofInputs[i + 5] = whitelisted;
        }
		bytes32 merkleRoot = bytes32(vm.ffi(inputs));
		console.logBytes32(merkleRoot);
		token.setMerkleRoot(merkleRoot);
    }

    function testClaim() public {
        proofInputs[CLAIM_SLOT] = addressToString(W1, 0);
        bytes32[] memory proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        for (uint256 i = 0; i < proof.length; i++) {
            console.logBytes32(proof[i]);
        }
        vm.startPrank(W1);
        token.claim(proof, 0);
    }

	/// Returns input tom erkle encoder in format `{ADDRESS}:{TOKEN_ID}`.
	function addressToString(address _address, uint256 index) public view returns(string memory) {
        uint256 len;
        uint256 j = index;
        while (j != 0) {
            ++len;
            j /= 10;
        }
		bytes32 _bytes = bytes32(uint256(uint160(_address)));
		bytes memory HEX = "0123456789abcdef";
		bytes memory _string = new bytes(43 + (index == 0 ? 1 : len));
		_string[0] = '0';
		_string[1] = 'x';
		for(uint i = 0; i < 20; i++) {
			_string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
			_string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
		}
        _string[42] = ":";
        if (index == 0) {
            _string[43] = "0";
        } 
        while (index != 0) {
            len -= 1;
            _string[43 + len] = bytes1(48 + uint8(index - index / 10 * 10));
            index /= 10;
        }
        console.log(string(_string));
		return string(_string);
	}
}
