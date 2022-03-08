// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./mocks/MockERC721.sol";
import "./mocks/MockERC721Receiver.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title ERC721 Test Suite
contract ERC721Test is Test {

    bytes4 constant RECEIVER_MAGIC_VALUE = 0x150b7a02;

	string constant NAME = "DOPAMINT PASS";
	string constant SYMBOL = "DOPE";

	uint256 constant MAX_SUPPLY = 10;

    uint256 constant NFT = 0;
    uint256 constant NFT_1 = 1;
    uint256 constant NONEXISTENT_NFT = 99;

    address constant FROM = address(1337);
    address constant TO = address(69);
    address constant OPERATOR = address(420);

    MockERC721 token;

    /// @notice ERC-721 emitted events.
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Event emitted to test ERC721 Receiver behavior.
    event ERC721Received(address operator, address from, uint256 tokenId, bytes data);

    /// @notice Used for subtests that modify state.
    modifier reset {
        _;
        setUp();
    }

    /// @dev All tests revolve around premise of `NFT` originating from `FROM`.
    function setUp() public {
        token = new MockERC721(NAME, SYMBOL, MAX_SUPPLY);
        token.mint(FROM, NFT);
        vm.startPrank(FROM);
    }

    function testMetadata() public {
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
    }

    function testBalanceOf() public {
        assertEq(token.balanceOf(FROM), 1);
        assertEq(token.balanceOf(TO), 0);
        assertEq(token.balanceOf(address(0)), 0);

        token.mint(FROM, NFT + 1);
        assertEq(token.balanceOf(FROM), 2);

        token.burn(NFT);
        assertEq(token.balanceOf(FROM), 1);
    }

    function testOwnerOf() public {
        assertEq(token.ownerOf(NFT), FROM);

        token.transferFrom(FROM, TO, NFT);
        assertEq(token.ownerOf(NFT), TO);

        token.burn(NFT);
        assertEq(token.ownerOf(NFT), address(0));
    }

    function testGetApproved() public {
        assertEq(token.getApproved(NONEXISTENT_NFT), address(0));
        assertEq(token.getApproved(NFT), address(0));

        token.approve(OPERATOR, NFT); 
        assertEq(token.getApproved(NFT), OPERATOR);

        token.approve(address(0), NFT);
        assertEq(token.getApproved(NFT), address(0));
    } 

    function testApprove() public {
        // Approval succeeds when owner approves.
        vm.expectEmit(true, true, true, true);
        emit Approval(FROM, OPERATOR, NFT);
        token.approve(OPERATOR, NFT);
        assertEq(token.getApproved(NFT), OPERATOR);

        // Approvals fail when invoked by the unauthorized address.
        vm.prank(OPERATOR);
        expectRevert("UnauthorizedSender()");
        token.approve(OPERATOR, NFT);

        // Approvals succeed when executed by the authorized operator.
        token.setApprovalForAll(OPERATOR, true);
        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit Approval(FROM, OPERATOR, NFT);
        token.approve(OPERATOR, NFT);
        assertEq(token.getApproved(NFT), OPERATOR);
    }

    function testIsApprovedForAll() public {
        assertTrue(!token.isApprovedForAll(FROM, OPERATOR));

        vm.startPrank(FROM);
        token.setApprovalForAll(OPERATOR, true);
        assertTrue(token.isApprovedForAll(FROM, OPERATOR));

        token.setApprovalForAll(OPERATOR, false);
        assertTrue(!token.isApprovedForAll(FROM, OPERATOR));
    }

    function testSetApprovalForAll() public {
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(FROM, OPERATOR, true);
        token.setApprovalForAll(OPERATOR, true);
        assertTrue(token.isApprovedForAll(FROM,OPERATOR));

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(FROM, OPERATOR, false);
        token.setApprovalForAll(OPERATOR, false);
        assertTrue(!token.isApprovedForAll(FROM,OPERATOR));
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(token.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(token.supportsInterface(0x5b5e139f)); // ERC721Metadata
    }

    function testMint() public {
        // Reverts when minting to the zero-address
        expectRevert("ZeroAddressReceiver()");
        token.mint(address(0), NFT);

        // Reverts when minting an already minted NFT.
        expectRevert("DuplicateMint()");
        token.mint(FROM, NFT);

        uint256 prevSupply = token.totalSupply();

        // Emits the expected `Transfer` event.
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), FROM, NFT_1);
        token.mint(FROM, NFT_1);

        // Correctly reassigns total supply and ownership.
        assertEq(token.ownerOf(NFT_1), FROM);
        assertEq(token.totalSupply(), prevSupply + 1);

        // Reverts when minting past maximum supply.
        for (uint256 i = 1; token.totalSupply() < MAX_SUPPLY; i++) {
            token.mint(FROM, NFT_1 + i);
        }
        expectRevert("SupplyMaxCapacity()");
        token.mint(FROM, MAX_SUPPLY);

        // Mint works again if another is first burned.
        token.burn(NFT);
        token.mint(FROM, MAX_SUPPLY);
    }

    function testBurn() public {
        // Reverts when burned NFT does not exist.
        expectRevert("NonExistentNFT()");
        token.burn(NFT_1);
        uint256 prevSupply = token.totalSupply();

        // Emits the expected `Transfer` event.
        vm.expectEmit(true, true, true, true);
        emit Transfer(FROM, address(0), NFT);
        token.burn(NFT);

        // Correctly reassigns total supply and ownership.
        assertEq(token.ownerOf(NFT), address(0));
        assertEq(token.totalSupply(), prevSupply - 1);
    }
    

    function testSafeTransferFromBehavior() public {
        _testSafeTransferBehavior(token.mockSafeTransferFromWithoutData, "");
        _testSafeTransferBehavior(token.mockSafeTransferFromWithData, token.DATA());
    }

    function testTransferFromBehavior() public {
        _testTransferBehavior(token.transferFrom);
        _testTransferBehavior(token.mockSafeTransferFromWithoutData);
        _testTransferBehavior(token.mockSafeTransferFromWithData);
    }

    function _testSafeTransferBehavior(
        function(address, address, uint256) external fn,
        bytes memory data
    ) internal {
        // Transferring to a contract
        _testSafeTransferFailure(fn);
        _testSafeTransferSuccess(fn, data);
    }

  	function _testSafeTransferFailure(function(address, address, uint256) external fn) internal {
        // Should throw when receiver magic value is invalid.
        MockERC721Receiver invalidReceiver = new MockERC721Receiver(0xDEADBEEF, false);
        expectRevert("InvalidReceiver()");
        fn(FROM, address(invalidReceiver), NFT);

        // Should throw when receiver function throws.
        invalidReceiver = new MockERC721Receiver(RECEIVER_MAGIC_VALUE, true);
        expectRevert("Throwing()");
        fn(FROM, address(invalidReceiver), NFT);

        // Should throw when receiver function is not implemented.
        vm.expectRevert(new bytes(0));
        fn(FROM, address(this), NFT);
    }

    function _testSafeTransferSuccess(
        function(address, address, uint256) external fn,
        bytes memory data
    ) internal reset {
        MockERC721Receiver validReceiver = new MockERC721Receiver(RECEIVER_MAGIC_VALUE, false);
        vm.expectEmit(true, true, true, true);
        emit ERC721Received(FROM, FROM, NFT, data);
        fn(FROM, address(validReceiver), NFT);

        assertEq(token.ownerOf(NFT), address(validReceiver));
    }

    function _testTransferBehavior(function(address, address, uint256) external fn) internal {
        // Test transfer failure conditions.
        _testTransferFailure(fn); 
        
        // Test normal transfers invoked via owner.
        _testTransferSuccess(token.transferFrom, FROM, TO);

        // Test transfers to self.
        _testTransferSuccess(token.transferFrom, FROM, FROM);

        // Test transfers through an approved address.
        token.approve(OPERATOR, NFT);
        _testTransferSuccess(token.transferFrom, OPERATOR, TO);

        // Test transfers through an authorized operator.
        token.setApprovalForAll(OPERATOR, true);
        _testTransferSuccess(token.transferFrom, OPERATOR, TO);
    }

    function _testTransferFailure(function(address, address, uint256) external fn) internal {
        expectRevert("ZeroAddressReceiver()");
        fn(FROM, address(0), NFT);

        expectRevert("InvalidOwner()");
        fn(TO, TO, NFT);

        vm.prank(TO);
        expectRevert("UnauthorizedSender()");
        fn(FROM, TO, NFT);
    }

    /// @dev Test successful transfer of `NFT` from `FROM` to `to`,
    ///  with `sender` as the transfer originator.
    function _testTransferSuccess(
        function(address, address, uint256) external fn,
        address sender,
        address to
    ) 
        internal reset
    {
        vm.expectEmit(true, true, true, true);
        emit Transfer(FROM, to, NFT);
        vm.prank(sender);
        token.transferFrom(FROM, to, NFT);

        if (to != FROM) {
            assertEq(0, token.balanceOf(FROM));
            assertEq(1, token.balanceOf(to));
        } else {
            assertEq(1, token.balanceOf(FROM));
        }

        assertEq(token.getApproved(NFT), address(0)); // Clear approvals
        assertEq(token.ownerOf(NFT), to);
    }

}