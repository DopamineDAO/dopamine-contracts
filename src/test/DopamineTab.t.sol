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
    address constant FROM = address(99);
    address constant TO = address(69);
    address constant OPERATOR = address(420);
    address constant RESERVE = address(123);
    address constant DAO = address(9);

    /// @notice Default auction house parameters.
    uint256 constant TREASURY_SPLIT = 30; // 50%
    uint256 constant TIME_BUFFER = 10 minutes;
    uint256 constant RESERVE_PRICE = 1 ether;

    uint256 constant AUCTION_DURATION = 60 * 60 * 12; // 12 hours
    IOpenSeaProxyRegistry PROXY_REGISTRY;
    DopamineTab token;
    DopamineAuctionHouse ah;

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    uint256 constant MAX_SUPPLY = 19;
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

    address[2] WHITELISTED = [
        W1, 
		W2
	];
    string[] proofInputs;
    string[] inputs;
    uint256 constant CLAIM_SLOT = 4;

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(TO);

        MockProxyRegistry r  = new MockProxyRegistry();
        r.registerProxy(); // Register OS delegate on behalf of `TO`.
        PROXY_REGISTRY = IOpenSeaProxyRegistry(address(r));

        vm.stopPrank();
        vm.startPrank(ADMIN);

        token = new DopamineTab(BASE_URI, ADMIN, address(PROXY_REGISTRY), DROP_DELAY, MAX_SUPPLY);

        DopamineAuctionHouse ahImpl = new DopamineAuctionHouse();
        address proxyAddr = getContractAddress(address(ADMIN), 0x02); 
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
            string memory allowlisted = addressToString(WHITELISTED[i], i);
            inputs[i + 3] = allowlisted;
            proofInputs[i + 5] = allowlisted;
        }
        vm.stopPrank();
    }

    function testIsApprovedForAll() public {
        // Users with registered OS delegates are approved automatically.
        assertTrue(token.isApprovedForAll(TO, PROXY_REGISTRY.proxies(TO)));

        // Otherwise, they are not.
        assertTrue(!token.isApprovedForAll(FROM, PROXY_REGISTRY.proxies(TO)));
    }

    function testConstructor() public {
        assertEq(token.minter(), ADMIN);
        assertEq(address(token.proxyRegistry()), address(PROXY_REGISTRY));
        assertEq(token.dropDelay(), DROP_DELAY);
        assertEq(token.dropEndIndex(), 0);
        assertEq(token.dropEndTime(), 0);

        // Reverts when setting invalid drop delay.
        uint256 maxDropDelay = token.MAX_DROP_DELAY();
        vm.expectRevert(DropDelayInvalid.selector);
        new DopamineTab(BASE_URI, ADMIN, address(PROXY_REGISTRY), maxDropDelay + 1, MAX_SUPPLY);

    }

    function testMint() public {
        vm.startPrank(ADMIN);
        // Mint reverts with no drops created.
        vm.expectRevert(DropMaxCapacity.selector);
        token.mint();

        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        // Mints should succeed till drop size is reached.
        for (uint256 i = 0; i < DROP_SIZE - ALLOWLIST_SIZE; i++) {
            token.mint();
        }

        // Mint reverts once drop capacity is reached.
        vm.expectRevert(DropMaxCapacity.selector);
        token.mint();

        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        // Minting continues working on next drop
        token.mint();
        vm.stopPrank();
    }

    function testCreateDrop() public {
        vm.startPrank(ADMIN);
        // Successfully creates a drop.
        vm.expectEmit(true, true, true, true);
        emit DropCreated(0, 0, DROP_SIZE, ALLOWLIST_SIZE, bytes32(0), PROVENANCE_HASH);
        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        assertEq(token.dropEndIndex(), DROP_SIZE);
        assertEq(token.dropEndTime(), BLOCK_TIMESTAMP + DROP_DELAY);

        // Should revert if drop creation called during ongoing drop.
        vm.expectRevert(DropOngoing.selector);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, bytes32(0), ALLOWLIST_SIZE, PROVENANCE_HASH);
        for (uint256 i = 0; i < DROP_SIZE - ALLOWLIST_SIZE; i++) {
            token.mint();
        }

        // Should revert if insufficient time has passed.
        vm.expectRevert(DropTooEarly.selector);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        // Should revert on creating a new drop if supply surpasses maximum.
        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        vm.expectRevert(DropMaxCapacity.selector);
        token.createDrop(1, DROP_SIZE, MAX_SUPPLY - DROP_SIZE + 1, bytes32(0), ALLOWLIST_SIZE, PROVENANCE_HASH);

        // Reverts if allowlist size too large.
        uint256 maxAllowlistSize = token.MAX_AL_SIZE();
        vm.expectRevert(DropAllowlistOverCapacity.selector);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, maxAllowlistSize + 1, bytes32(0));

        // Reverts if larger than drop size.
        vm.expectRevert(DropAllowlistOverCapacity.selector);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, DROP_SIZE + 1, bytes32(0));

        // Reverts if the drop size is too low.
        uint256 minDropSize = token.MIN_DROP_SIZE();
        vm.expectRevert(DropSizeInvalid.selector);
        token.createDrop(1, DROP_SIZE, minDropSize - 1, PROVENANCE_HASH, 0, bytes32(0));

        // Reverts if the drop size is too high.
        uint256 maxDropSize = token.MAX_DROP_SIZE();
        vm.expectRevert(DropSizeInvalid.selector);
        token.createDrop(1, DROP_SIZE, maxDropSize + 1, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        // Should not revert and emit the expected DropCreated logs otherwise.
        vm.expectEmit(true, true, true, true);
        emit DropCreated(1, DROP_SIZE, MAX_SUPPLY - DROP_SIZE, ALLOWLIST_SIZE,  bytes32(0), PROVENANCE_HASH);
        token.createDrop(1, DROP_SIZE, MAX_SUPPLY - DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        vm.stopPrank();
    }

    function testSetMinter() public {
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit MinterChanged(ADMIN, TO);
        token.setMinter(TO);
        assertEq(token.minter(), TO);
        vm.stopPrank();
    }

    function testSetDropDelay() public {
        vm.startPrank(ADMIN);
        // Reverts if the drop delay is too low.
        uint256 minDropDelay = token.MIN_DROP_DELAY();
        vm.expectRevert(DropDelayInvalid.selector);
        token.setDropDelay(minDropDelay - 1);

        // Reverts if the drop delay is too high.
        uint256 maxDropDelay = token.MAX_DROP_DELAY();
        vm.expectRevert(DropDelayInvalid.selector);
        token.setDropDelay(maxDropDelay + 1);

        // Emits expected DropDelaySet event.
        vm.expectEmit(true, true, true, true);
        emit DropDelaySet(DROP_DELAY);
        token.setDropDelay(DROP_DELAY);
        vm.stopPrank();
    }

    function testSetDropSize() public {
        vm.startPrank(ADMIN);
    }

    function testSetBaseURI() public {
        vm.startPrank(ADMIN);
        // Should change the base URI of the NFT.
        vm.expectEmit(true, true, true, true);
        emit BaseURISet("https://dopam1ne.xyz");
        token.setBaseURI("https://dopam1ne.xyz");

        assertEq(token.baseURI(), "https://dopam1ne.xyz");
        vm.stopPrank();
    }

    function testSetDropURI() public {
        vm.startPrank(ADMIN);
        // Reverts when drop has not yet been created.
        vm.expectRevert(DropNonExistent.selector);
        token.setDropURI(0, IPFS_URI);

        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        vm.expectEmit(true, true, true, true);
        emit DropURISet(0, IPFS_URI);
        token.setDropURI(0, IPFS_URI);
        vm.stopPrank();
    }

    function testTokenURI() public {
        vm.startPrank(ADMIN);
        // Reverts when token not yet minted.
        vm.expectRevert(TokenNonExistent.selector);
        token.tokenURI(NFT);

        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        token.mint();
        assertEq(token.tokenURI(NFT), "https://api.dopamine.xyz/metadata/2");

        token.setDropURI(0, IPFS_URI);
        assertEq(token.tokenURI(NFT), "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/2");
        vm.stopPrank();
    }

    function testGetDropId() public {
        vm.startPrank(ADMIN);
        // Reverts when token of drop has not yet been created.
        vm.expectRevert(DropNonExistent.selector);
        token.dropId(NFT);

        // Once minted, NFT assigned the correct drop.
        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        token.mint();
        assertEq(token.dropId(NFT), 0);

        // Last token of collection assigned correct drop id.
        for (uint256 i = 0; i < DROP_SIZE - ALLOWLIST_SIZE - 1; i++) {
            token.mint();
        }
        assertEq(token.dropId(DROP_SIZE - 1), 0);

        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        token.mint();
        assertEq(token.dropId(DROP_SIZE + ALLOWLIST_SIZE), 1);
        vm.stopPrank();
    }

    function testClaim() public {
        vm.startPrank(ADMIN);
        // Create drop with allowlist.
        bytes32 merkleRoot = bytes32(vm.ffi(inputs));
        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, merkleRoot);

        // First allowlisted user can claim assigned NFT.
        proofInputs[CLAIM_SLOT] = addressToString(W1, 0);
        bytes32[] memory proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        vm.stopPrank();
        vm.startPrank(W1);
        token.claim(proof, 0);
        assertEq(token.ownerOf(0), W1);

        // Claiming same NFT twice fails.
        vm.expectRevert(TokenAlreadyMinted.selector);
        token.claim(proof, 0);

        // Claiming wrong NFT reverts due to invalid proof.
        vm.expectRevert(ProofInvalid.selector);
        token.claim(proof, 1);

        // Proof presented by wrong owner fails.
        proofInputs[CLAIM_SLOT] = addressToString(W2, 1);
        proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        vm.expectRevert(ProofInvalid.selector);
        token.claim(proof, 0);

        // Works for allowlisted member.
        vm.stopPrank();
        vm.startPrank(W2);
        token.claim(proof, 1);
        assertEq(token.ownerOf(1), W2);
        vm.stopPrank();
    }

    function testUnclaimed() public {
        vm.startPrank(ADMIN);
        // Create drop with allowlist.
        bytes32 merkleRoot = bytes32(vm.ffi(inputs));
        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, merkleRoot);
        vm.stopPrank();

        vm.startPrank(W1);
        // First allowlisted user can claim assigned NFT.
        proofInputs[CLAIM_SLOT] = addressToString(W1, 0);
        bytes32[] memory proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        token.claim(proof, 0);
        assertEq(token.ownerOf(0), W1);
        vm.stopPrank();
        
        vm.startPrank(ADMIN);
        inputs[3] = addressToString(W2, 1);
        inputs[4] = addressToString(W3, 9);
        proofInputs[5] = addressToString(W2, 1);
        proofInputs[6] = addressToString(W3, 9);
        // Create drop with unclaimed allowlist.
        merkleRoot = bytes32(vm.ffi(inputs));
        for (uint256 i = 0; i < DROP_SIZE - ALLOWLIST_SIZE; i++) {
            token.mint();
        }
        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.createDrop(1, DROP_SIZE, DROP_SIZE, PROVENANCE_HASH, 1, merkleRoot);

        // Third allowlisted user can claim unclaimed NFT for drop #1.
        vm.stopPrank();

        vm.startPrank(W3);
        proofInputs[CLAIM_SLOT] = addressToString(W3, 9);
        proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        token.claim(proof, 9);
        assertEq(token.ownerOf(9), W3);
        vm.stopPrank();

        // Second allowlisted user can claim unclaimed NFT for drop #0.
        vm.startPrank(W2);
        proofInputs[CLAIM_SLOT] = addressToString(W2, 1);
        proofInputs[5] = addressToString(W1, 0);
        proofInputs[6] = addressToString(W2, 1);
        proof = abi.decode(vm.ffi(proofInputs), (bytes32[]));
        token.claim(proof, 1);
        assertEq(token.ownerOf(1), W2);
        vm.stopPrank();
    }

    function testAuctions() public {
        vm.startPrank(ADMIN);
        token.setMinter(address(ah));
        token.createDrop(0, 0, DROP_SIZE, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));

        ah.resumeNewAuctions();
        vm.stopPrank();
    }

    function testFuzz(uint96 dropSize) public {
        vm.assume(dropSize < 15_000);
        
        vm.startPrank(ADMIN);
        token = new DopamineTab(BASE_URI, ADMIN, address(PROXY_REGISTRY), DROP_DELAY, 1e10);
        console.log(dropSize);
        // Create drop with allowlist.
        if (ALLOWLIST_SIZE > dropSize) {
            vm.expectRevert(DropAllowlistOverCapacity.selector);
        } else if (dropSize <= token.MIN_DROP_SIZE()) {
            vm.expectRevert(DropSizeInvalid.selector);
        } else if (dropSize >= token.MAX_DROP_SIZE()) {
            vm.expectRevert(DropSizeInvalid.selector);
        }
        token.createDrop(0, 0, dropSize, PROVENANCE_HASH, ALLOWLIST_SIZE, bytes32(0));
        
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
