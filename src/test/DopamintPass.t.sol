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

    /// @notice Whitelisted addresses.
    address[2] WHITELISTED = [
        W1,
        address(12)
    ];
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
        string[] memory inputs = new string[](5);
        proofInputs = new string[](7);
        proofInputs[0] = "npx";
        proofInputs[1] = "hardhat";
        proofInputs[2] = "merkleproof";
        proofInputs[3] = "--address";
        inputs[0] = "npx";
        inputs[1] = "hardhat";
        inputs[2] = "merkle";
        for (uint256 i = 0; i < 2; i++) {
            string memory whitelisted = addressToString(WHITELISTED[i]);
            inputs[i + 3] = whitelisted;
            proofInputs[i + 5] = whitelisted;
        }
		bytes32 merkleRoot = bytes32(vm.ffi(inputs));
		console.logBytes32(merkleRoot);
		token.setMerkleRoot(merkleRoot);
    }

    function testClaim() public {
        proofInputs[CLAIM_SLOT] = addressToString(W1);
        bytes memory proof = vm.ffi(proofInputs);
        token.claim(bytesToBytes32Array(proof));
    }

	/// @notice Taken from https://ethereum.stackexchange.com/questions/70300/how-to-convert-an-ethereum-address-to-an-ascii-string-in-solidity/70301
	function addressToString(address _address) public pure returns(string memory) {
		bytes32 _bytes = bytes32(uint256(uint160(_address)));
		bytes memory HEX = "0123456789abcdef";
		bytes memory _string = new bytes(42);
		_string[0] = '0';
		_string[1] = 'x';
		for(uint i = 0; i < 20; i++) {
			_string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
			_string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
		}
		return string(_string);
	}

	function bytesToBytes32Array(bytes memory data)
		public
		pure
		returns (bytes32[] memory)
	{
		// Find 32 bytes segments nb
		uint256 dataNb = data.length / 32;
		// Create an array of dataNb elements
		bytes32[] memory dataList = new bytes32[](dataNb);
		// Start array index at 0
		uint256 index = 0;
		// Loop all 32 bytes segments
		for (uint256 i = 32; i <= data.length; i = i + 32) {
			bytes32 temp;
			// Get 32 bytes from data
			assembly {
				temp := mload(add(data, i))
			}
			// Add extracted 32 bytes to list
			dataList[index] = temp;
			index++;
		}
		// Return data list
		return (dataList);
	}

}
