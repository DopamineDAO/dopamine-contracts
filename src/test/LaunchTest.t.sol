// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../interfaces/IDopamineTab.sol";
import "../interfaces/IOpenSeaProxyRegistry.sol";
import "./mocks/MockDopamineAuctionHouse.sol";
import "../auction/DopamineAuctionHouse.sol";
import "../interfaces/IDopamineAuctionHouse.sol";
import "../nft/DopamineTab.sol";
import "./mocks/MockProxyRegistry.sol";

import "./utils/test.sol";
import "./utils/console.sol";

contract MockContractUnpayable { }
contract MockContractPayable { receive() external payable {} }

/// @title Dopamint Tab Test Suites
contract DopamineTabTest is Test, IDopamineTabEvents {

    string constant BASE_URI = "https://api.dopamine.xyz/metadata/";

    /// @notice Addresses used for testing.
    address constant ADMIN = address(1337);
    address constant BIDDER = address(99);
    address constant BIDDER_1 = address(89);
    address constant RESERVE = address(123);
    address constant DAO = address(9);
    address constant TO = address(69);

    uint256 constant BIDDER_INITIAL_BAL = 8888 ether;
    uint256 constant BIDDER_1_INITIAL_BAL = 100 ether;

    /// @notice Default auction house parameters.
    uint256 constant TREASURY_SPLIT = 40; // 40%
    uint256 constant TIME_BUFFER = 10 minutes;
    uint256 constant RESERVE_PRICE = 1 ether;

    uint256 constant AUCTION_DURATION = 60 * 60 * 12; // 12 hours
    IOpenSeaProxyRegistry PROXY_REGISTRY;
    DopamineTab token;
    DopamineAuctionHouse ah;

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    uint256 constant MAX_SUPPLY = 110;
    uint256 constant DROP_SIZE = 9;
    uint256 constant DROP_DELAY = 4 weeks;
    uint256 constant ALLOWLIST_SIZE = 2;

    uint256 constant NFT = ALLOWLIST_SIZE;
    uint256 constant NFT_1 = ALLOWLIST_SIZE + 1;

    bytes32 PROVENANCE_HASH = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;
    string constant IPFS_URI = "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/";

    /// @notice Allowlist test addresses.
    address constant W1 = address(0x683C3ac15e4E024E1509505B9a8F3f7B1A1cFf1e);
    address constant W2 = address(0x69BABE250214d876BeEEA087945F0B53F691D519);
    address constant W3 = address(0xA32F30ce77AAbBBfcB926FB449Ae44A5Cb2a8b77);

    address[3] WHITELISTED = [
        W1, 
		W2,
        W3
	];
    string[] proofInputs;
    string[] inputs;
    uint256 constant CLAIM_SLOT = 4;

    /// @notice Emits when auction creation fails (due to NFT mint reverting).
    event AuctionCreationFailed();

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(TO);

        vm.deal(BIDDER, BIDDER_INITIAL_BAL);
        vm.deal(BIDDER_1, BIDDER_1_INITIAL_BAL);

        MockProxyRegistry r  = new MockProxyRegistry();
        r.registerProxy(); // Register OS delegate on behalf of `TO`.
        PROXY_REGISTRY = IOpenSeaProxyRegistry(address(r));

        vm.stopPrank();
        vm.startPrank(ADMIN);
        address proxyAddr = getContractAddress(address(ADMIN), 0x02); 
        token = new DopamineTab(BASE_URI, proxyAddr, address(PROXY_REGISTRY), DROP_DELAY, MAX_SUPPLY);

        DopamineAuctionHouse ahImpl = new DopamineAuctionHouse();
        
        bytes memory data = abi.encodeWithSelector(
            ahImpl.initialize.selector,
            address(token),
            RESERVE,
            DAO,
            TREASURY_SPLIT,
            TIME_BUFFER,
            RESERVE_PRICE,
            AUCTION_DURATION
        );
		ERC1967Proxy proxy = new ERC1967Proxy(address(ahImpl), data);
        ah = DopamineAuctionHouse(address(proxy));

        // 3 inputs for CLI args
        inputs = new string[](3 + WHITELISTED.length);
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
            string memory allowlisted = addressToString(WHITELISTED[i], i + 1);
            inputs[i + 3] = allowlisted;
            proofInputs[i + 5] = allowlisted;
        }
        vm.stopPrank();
    }

    function testDropAndClaim() public {
        // Create first drop for 1 tab
        vm.startPrank(ADMIN);
        token.createDrop(0, 0, 1, PROVENANCE_HASH, 0, bytes32(0));
        ah.resumeNewAuctions();
        vm.stopPrank();

        // First bid with 1 ether
        vm.startPrank(BIDDER);
        ah.createBid{ value: 1 ether }(0);
        assertEq(BIDDER.balance, BIDDER_INITIAL_BAL - 1 ether);
        vm.stopPrank();

        vm.startPrank(BIDDER_1);
        ah.createBid{ value: 2 ether }(0);
        assertEq(BIDDER_1.balance, BIDDER_1_INITIAL_BAL - 2 ether);

        // Refunds to first bidder
        assertEq(BIDDER.balance, BIDDER_INITIAL_BAL);
        vm.warp(BLOCK_TIMESTAMP + AUCTION_DURATION);
        vm.expectEmit(true, true, true, true);
        emit AuctionCreationFailed();
        ah.settleAuction();
        assertEq(token.ownerOf(0), BIDDER_1);
        vm.stopPrank();

        // Create second drop for 99 tab, 3 whitelisted
        vm.startPrank(ADMIN);
        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        bytes32 merkleRoot = bytes32(vm.ffi(inputs));
        token.createDrop(1, 1, 99, PROVENANCE_HASH, 3, merkleRoot);
        vm.expectRevert(AuctionAlreadySuspended.selector);
        ah.suspendNewAuctions();
        ah.resumeNewAuctions();
        vm.stopPrank();

        // Auction again
        vm.startPrank(BIDDER_1);
        ah.createBid{ value: 1 ether }(4);
        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY + AUCTION_DURATION);
        ah.settleAuction();
        assertEq(token.ownerOf(4), BIDDER_1);
        vm.stopPrank();

        // Claim test
        vm.startPrank(W1);
        proofInputs[CLAIM_SLOT] = addressToString(W1, 1);
        bytes32[] memory proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        token.claim(proof, 1);
        assertEq(token.ownerOf(1), W1);
        vm.stopPrank();

        // Auction loop for 98 Tabs
        vm.startPrank(BIDDER);
        for (uint256 i = 0; i < 95; i++) {
            ah.createBid{ value: 2 ether }(i + 5);
            vm.warp(BLOCK_TIMESTAMP + DROP_DELAY + AUCTION_DURATION * (i + 2));
            ah.settleAuction();
            assertEq(token.ownerOf(i + 5), BIDDER);
        }
        vm.stopPrank();

        // Create third drop for 10 tabs
        vm.startPrank(ADMIN);
        token.createDrop(2, 100, 10, PROVENANCE_HASH, 0, bytes32(0));
        ah.resumeNewAuctions();
        vm.stopPrank();

        // Claim Tabs for previous drop
        vm.startPrank(W2);
        proofInputs[CLAIM_SLOT] = addressToString(W2, 2);
        proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        token.claim(proof, 2);
        assertEq(token.ownerOf(2), W2);
        vm.stopPrank();
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
		return string(_string);
	}
}
