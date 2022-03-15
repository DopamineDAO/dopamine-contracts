// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../interfaces/IDopamintPass.sol";
import "../DopamintPass.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title Dopamint Pass Test Suites
contract DopamintPassTest is Test, IDopamintPassEvents {

    /// @notice Addresses used for testing.
    address constant OWNER = address(1337);
    address constant FROM = address(99);
    address constant TO = address(69);
    address constant OPERATOR = address(420);

    address constant PROXY_REGISTRY = address(12629);

    DopamintPass token;

    /// @notice Block settings for testing.
    uint256 constant BLOCK_TIMESTAMP = 9999;
    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    uint256 constant MAX_SUPPLY = 19;
    uint256 constant DROP_SIZE = 9;
    uint256 constant DROP_DELAY = 4 weeks;
    uint256 constant WHITELIST_SIZE = 5;

    uint256 constant NFT = WHITELIST_SIZE;
    uint256 constant NFT_1 = WHITELIST_SIZE + 1;

    bytes32 PROVENANCE_HASH = 0xf21123649788fb044e6d832e66231b26867af618ea80221e57166f388c2efb2f;
    string IPFS_URI = "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/";

    /// @notice Whitelist test addresses.
    address constant W1 = address(9210283791031090);
    address constant W2 = address(1928327197379129);

    address[4] WHITELISTED = [
        W1, 
        address(291909102),
        W2,
        address(21828118)
    ];
    string[] proofInputs;
    string[] inputs;
    uint256 constant CLAIM_SLOT = 4;

    function setUp() public virtual {
        vm.roll(BLOCK_START);
        vm.warp(BLOCK_TIMESTAMP);
        vm.startPrank(OWNER);

        token = new DopamintPass(OWNER, IProxyRegistry(PROXY_REGISTRY), DROP_SIZE, DROP_DELAY, WHITELIST_SIZE, MAX_SUPPLY);

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
            string memory whitelisted = addressToString(WHITELISTED[i], i);
            inputs[i + 3] = whitelisted;
            proofInputs[i + 5] = whitelisted;
        }
    }

    function testConstructor() public {
        assertEq(token.minter(), OWNER);
        assertEq(address(token.proxyRegistry()), PROXY_REGISTRY);
        assertEq(token.dropSize(), DROP_SIZE);
        assertEq(token.dropDelay(), DROP_DELAY);
        assertEq(token.whitelistSize(), WHITELIST_SIZE);
        assertEq(token.dropEndIndex(), 0);
        assertEq(token.dropEndTime(), 0);

        // Reverts when setting invalid drop size.
        uint256 minDropSize = token.MIN_DROP_SIZE();
        vm.expectRevert(InvalidDropSize.selector);
        new DopamintPass(OWNER, IProxyRegistry(PROXY_REGISTRY), minDropSize - 1, DROP_DELAY, WHITELIST_SIZE, MAX_SUPPLY);
        
        // Reverts when setting invalid drop delay.
        uint256 maxDropDelay = token.MAX_DROP_DELAY();
        vm.expectRevert(InvalidDropDelay.selector);
        new DopamintPass(OWNER, IProxyRegistry(PROXY_REGISTRY), DROP_SIZE, maxDropDelay + 1, WHITELIST_SIZE, MAX_SUPPLY);

    }

    function testMint() public {
        // Mint reverts with no drops created.
        vm.expectRevert(DropMaxCapacity.selector);
        token.mint();

        token.createDrop(bytes32(0), PROVENANCE_HASH);
        // Mints should succeed till drop size is reached.
        for (uint256 i = 0; i < DROP_SIZE - WHITELIST_SIZE; i++) {
            token.mint();
        }

        // Mint reverts once drop capacity is reached.
        vm.expectRevert(DropMaxCapacity.selector);
        token.mint();

        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.createDrop(bytes32(0), PROVENANCE_HASH);

        // Minting continues working on next drop
        token.mint();
    }

    function testCreateDrop() public {
        // Successfully creates a drop.
        vm.expectEmit(true, true, true, true);
        emit DropCreated(0, 0, DROP_SIZE, WHITELIST_SIZE, bytes32(0), PROVENANCE_HASH);
        token.createDrop(bytes32(0), PROVENANCE_HASH);

        assertEq(token.whitelistSize(), WHITELIST_SIZE);
        assertEq(token.dropEndIndex(), DROP_SIZE);
        assertEq(token.dropEndTime(), BLOCK_TIMESTAMP + DROP_DELAY);

        // Should revert if drop creation called during ongoing drop.
        vm.expectRevert(OngoingDrop.selector);
        token.createDrop(bytes32(0), PROVENANCE_HASH);
        for (uint256 i = 0; i < DROP_SIZE - WHITELIST_SIZE; i++) {
            token.mint();
        }

        // Should revert if insufficient time has passed.
        vm.expectRevert(InsufficientTimePassed.selector);
        token.createDrop(bytes32(0), PROVENANCE_HASH);

        // Should revert on creating a new drop if supply surpasses maximum.
        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.setDropSize(MAX_SUPPLY - DROP_SIZE + 1);
        vm.expectRevert(DropMaxCapacity.selector);
        token.createDrop(bytes32(0), PROVENANCE_HASH);

        // Should not revert and emit the expected DropCreated logs otherwise.
        token.setDropSize(MAX_SUPPLY - DROP_SIZE);
        vm.expectEmit(true, true, true, true);
        emit DropCreated(1, DROP_SIZE, MAX_SUPPLY - DROP_SIZE, WHITELIST_SIZE, bytes32(0), PROVENANCE_HASH);
        token.createDrop(bytes32(0), PROVENANCE_HASH);
    }

    function testSetMinter() public {
        vm.expectEmit(true, true, true, true);
        emit NewMinter(OWNER, TO);
        token.setMinter(TO);
        assertEq(token.minter(), TO);
    }

    function testSetDropDelay() public {
        // Reverts if the drop delay is too low.
        uint256 minDropDelay = token.MIN_DROP_DELAY();
        vm.expectRevert(InvalidDropDelay.selector);
        token.setDropDelay(minDropDelay - 1);

        // Reverts if the drop delay is too high.
        uint256 maxDropDelay = token.MAX_DROP_DELAY();
        vm.expectRevert(InvalidDropDelay.selector);
        token.setDropDelay(maxDropDelay + 1);

        // Emits expected DropDelaySet event.
        vm.expectEmit(true, true, true, true);
        emit DropDelaySet(DROP_DELAY);
        token.setDropDelay(DROP_DELAY);
    }

    function testSetDropSize() public {
        // Reverts if the drop size is too low.
        uint256 minDropSize = token.MIN_DROP_SIZE();
        vm.expectRevert(InvalidDropSize.selector);
        token.setDropSize(minDropSize - 1);

        // Reverts if the drop size is too high.
        uint256 maxDropSize = token.MAX_DROP_SIZE();
        vm.expectRevert(InvalidDropSize.selector);
        token.setDropSize(maxDropSize + 1);

        // Emits expected DropSizeSet event.
        vm.expectEmit(true, true, true, true);
        emit DropSizeSet(DROP_SIZE);
        token.setDropSize(DROP_SIZE);
        assertEq(token.dropSize(), DROP_SIZE);
    }


    function testSetWhitelistSize() public {
        // Reverts if whitelist size too large.
        uint256 maxWhitelistSize = token.MAX_WHITELIST_SIZE();
        vm.expectRevert(InvalidWhitelistSize.selector);
        token.setWhitelistSize(maxWhitelistSize + 1);

        // Reverts if larger than drop size.
        vm.expectRevert(InvalidWhitelistSize.selector);
        token.setWhitelistSize(DROP_SIZE + 1);

        // Emits expected WhitelistSizeSet event.
        vm.expectEmit(true, true, true, true);
        emit WhitelistSizeSet(WHITELIST_SIZE);
        token.setWhitelistSize(WHITELIST_SIZE);
    }

    function testSetDropURI() public {
        // Reverts when drop has not yet been created.
        vm.expectRevert(NonExistentDrop.selector);
        token.setDropURI(0, IPFS_URI);

        token.createDrop(bytes32(0), PROVENANCE_HASH);
        vm.expectEmit(true, true, true, true);
        emit DropURISet(0, IPFS_URI);
        token.setDropURI(0, IPFS_URI);
    }

    function testTokenURI() public {
        // Reverts when token not yet minted.
        vm.expectRevert(NonExistentNFT.selector);
        token.tokenURI(NFT);

        token.createDrop(bytes32(0), PROVENANCE_HASH);
        token.mint();
        assertEq(token.tokenURI(NFT), "https://dopamine.xyz/5");

        token.setDropURI(0, IPFS_URI);
        assertEq(token.tokenURI(NFT), "https://ipfs.io/ipfs/Qme57kZ2VuVzcj5sC3tVHFgyyEgBTmAnyTK45YVNxKf6hi/5");


    }

    function testGetDropId() public {
        // Reverts when token of drop has not yet been created.
        vm.expectRevert(NonExistentNFT.selector);
        token.getDropId(NFT);

        // Even on drop creation, reverts if token not yet minted.
        token.createDrop(bytes32(0), PROVENANCE_HASH);
        vm.expectRevert(NonExistentNFT.selector);
        token.getDropId(NFT);

        // Once minted, NFT assigned the correct drop.
        token.mint();
        assertEq(token.getDropId(NFT), 0);

        // Last token of collection assigned correct drop id.
        for (uint256 i = 0; i < DROP_SIZE - WHITELIST_SIZE - 1; i++) {
            token.mint();
        }
        assertEq(token.getDropId(DROP_SIZE - 1), 0);

        vm.warp(BLOCK_TIMESTAMP + DROP_DELAY);
        token.createDrop(bytes32(0), PROVENANCE_HASH);
        token.mint();
        assertEq(token.getDropId(DROP_SIZE + WHITELIST_SIZE), 1);
    }

    function _testClaim() public {
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
		return string(_string);
	}
}
