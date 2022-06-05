// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./mocks/MockERC721Votable.sol";

import {Test} from "./utils/test.sol";

struct Checkpoint {
    uint32 fromBlock;
    uint32 votes;
}
/// @title ERC721Votable Test Suite
contract ERC721VotableTest is Test {

	uint256 constant MAX_SUPPLY = 10;

    uint256 constant BLOCK_START = 99; // Testing starts at this block.

    uint256 constant TIMESTAMP_START = 9;
    uint256 constant TIMESTAMP_EXPIRY = 999; // When signature expected to expire.

    uint256 constant PK_FROM = 1;
    uint256 constant PK_TO = 2;
    uint256 constant PK_OPERATOR = 3;
    uint256[3] PKS = [PK_FROM, PK_TO, PK_OPERATOR];

    uint256 constant NFT = 0;
    uint256 constant NFT_1 = 1;
    uint256 constant NFT_2 = 2;
    uint256 constant NONEXISTENT_NFT = 99;

    address FROM;
    address TO;
    address OPERATOR;

    MockERC721Votable token;

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 oldBalance,
        uint256 newBalance
    );

    // To be called between internal testing functions to reset state.
    modifier reset {
        _;
        token.reset([FROM, TO, OPERATOR]);
        vm.roll(BLOCK_START);
        token.mint(FROM, NFT);
        vm.roll(BLOCK_START + 1);
        vm.stopPrank();
        vm.startPrank(FROM);
    }

    function setUp() public {
        FROM = vm.addr(PK_FROM);
        TO = vm.addr(PK_TO);
        OPERATOR = vm.addr(PK_OPERATOR);
        vm.stopPrank();
        vm.startPrank(FROM);

        token = new MockERC721Votable(MAX_SUPPLY);
        vm.roll(BLOCK_START);
        vm.warp(TIMESTAMP_START);
        token.mint(FROM, NFT);
        vm.roll(BLOCK_START + 1);
    }

    function testTransfer() public {
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 0, 1);
        token.transferFrom(FROM, TO, NFT);
        vm.roll(BLOCK_START + 2);

        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.totalCheckpoints(FROM), 2);
        assertEq(token.currentVotes(TO), 1);
        assertEq(token.totalCheckpoints(TO), 1);

        assertEq(token.priorVotes(FROM, BLOCK_START), 1);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(TO, BLOCK_START), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 1), 1);
    }

    function testMint() public {
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 0, 1);
        token.mint(TO, NFT_1);
        vm.roll(BLOCK_START + 2);

        assertEq(token.priorVotes(TO, BLOCK_START), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 1), 1);
        assertEq(token.currentVotes(TO), 1);
        assertEq(token.totalCheckpoints(TO), 1);
    }

    function testBurn() public {
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        token.burn(NFT);
        vm.roll(BLOCK_START + 2);

        assertEq(token.priorVotes(FROM, BLOCK_START), 1);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 0);
        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.totalCheckpoints(FROM), 2);
    }

    function testDelegate() public {
        _testDelegateBehavior(token.delegate);
    }

    function testDelegateBySig() public {
        token.initSigners(PKS);
        _testDelegateBehavior(token.mockDelegateBySig);
    }

    function testDelegateBySigSecurity() public {
        bytes32 domainSeparator = 
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(token.name())),
                    keccak256("1"),
                    block.chainid,
                    address(token)
                )
            );
        bytes32 structHash = 
            keccak256(
                abi.encode(
                    keccak256("Delegate(address delegator,address delegatee,uint256 nonce,uint256 expiry)"),
                    FROM,
                    TO,
                    token.nonces(FROM),
                    TIMESTAMP_EXPIRY
                )
            );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK_FROM, hash);

        // Reverts when block.timestamp past expiration.
        vm.warp(TIMESTAMP_EXPIRY + 1);
        vm.expectRevert(SignatureExpired.selector);
        token.delegateBySig(FROM, TO, TIMESTAMP_EXPIRY, v, r, s);

        // Reverts if incorrect parameter is passed in.
        vm.warp(TIMESTAMP_START);
        vm.expectRevert(SignatureInvalid.selector);
        token.delegateBySig(FROM, TO, 99999, v, r, s);

        token.delegateBySig(FROM, TO, TIMESTAMP_EXPIRY, v, r, s);

        // Reverts if same signature used twice.
        vm.expectRevert(SignatureInvalid.selector);
        token.delegateBySig(FROM, TO, TIMESTAMP_EXPIRY, v, r, s);
    }

    function _testDelegateBehavior(function(address) external fn) internal {
        vm.stopPrank();
        _testDelegateZeroBalance(fn);
        _testDelegateToSelf(fn);
        _testDelegateToValidAddress(fn);
        _testTransferWithSenderDelegate(fn);
        _testTransferWithReceiverDelegate(fn);
        _testDelegateWithMultipleTransfers(fn);
    }

    function _testDelegateZeroBalance(function(address) external fn) public reset {

        vm.prank(OPERATOR); // zero balance

        // Emits expected events.
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(OPERATOR, OPERATOR, TO);
        fn(TO);

        // Delegatee should change.
        assertEq(token.delegates(OPERATOR), TO);

        // Voting balances should remain the same.
        assertEq(token.currentVotes(OPERATOR), 0);

        // No checkpoints should be created.
        assertEq(token.totalCheckpoints(OPERATOR), 0);

        // Votes should be 0 for all previous voting blocks.
        vm.roll(BLOCK_START + 2);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START), 0);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 1), 0);
    }

    function _testDelegateToSelf(function(address) external fn) public reset {
        // Emits expected events when delegating to self
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(FROM, FROM, FROM);
        fn(FROM);

        // Delegatee should remain as self.
        assertEq(token.delegates(FROM), FROM);

        // Voting balances should remain the same.
        assertEq(token.currentVotes(FROM), 1);

        // No additional checkpoints should be created.
        assertEq(token.totalCheckpoints(FROM), 1);
        (uint32 fromBlock, uint32 votes) = token.checkpoints(FROM, 0);
        assertEq(fromBlock, BLOCK_START);
        assertEq(votes, 1);

        // Prior votes should be correctly recorded.
        vm.roll(BLOCK_START + 2);
        assertEq(token.priorVotes(FROM, BLOCK_START), 1);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 1);
    }

    function _testDelegateToValidAddress(function(address) external fn) public reset {
        // Emits expected events when delegating to a valid address.
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(FROM, FROM, TO);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 0, 1);
        fn(TO);

        // Delegatee should be correctly reassigned.
        assertEq(token.delegates(FROM), TO);

        // Voting balances should be adjusted.
        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.currentVotes(TO), 1);

        // Checkpoints hold expected values.
        assertEq(token.totalCheckpoints(FROM), 2);
        (uint32 fromBlock, uint32 votes) = token.checkpoints(FROM, 0);
        assertEq(fromBlock, BLOCK_START);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(FROM, 1);
        assertEq(fromBlock, BLOCK_START + 1);
        assertEq(votes, 0);

        assertEq(token.totalCheckpoints(TO), 1);
        (fromBlock, votes) = token.checkpoints(TO, 0);
        assertEq(fromBlock, BLOCK_START + 1);
        assertEq(votes, 1);

        // Prior votes should be correctly recorded.
        vm.roll(BLOCK_START + 2);
        assertEq(token.priorVotes(FROM, BLOCK_START), 1);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(TO, BLOCK_START), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 1), 1);
    }

    function _testTransferWithSenderDelegate(function(address) external fn) public reset {
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(FROM, FROM, OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 0, 1);
        fn(OPERATOR);

        vm.roll(BLOCK_START + 2);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 0, 1);
        token.transferFrom(FROM, TO, NFT);

        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.currentVotes(OPERATOR), 0);
        assertEq(token.currentVotes(TO), 1);

        assertEq(token.totalCheckpoints(FROM), 2);
        (uint32 fromBlock, uint32 votes) = token.checkpoints(FROM, 1);
        assertEq(fromBlock, BLOCK_START + 1);
        assertEq(votes, 0);

        assertEq(token.totalCheckpoints(OPERATOR), 2);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 0);
        assertEq(fromBlock, BLOCK_START + 1);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 1);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 0);

        assertEq(token.totalCheckpoints(TO), 1);
        (fromBlock, votes) = token.checkpoints(TO, 0);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 1);

        vm.roll(BLOCK_START + 3);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(FROM, BLOCK_START + 2), 0);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 1), 1);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 2), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 2), 1);
    }

    function _testTransferWithReceiverDelegate(function(address) external fn) public reset {
        vm.stopPrank();
        vm.startPrank(TO);
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(TO, TO, OPERATOR);
        fn(OPERATOR);

        vm.roll(BLOCK_START + 2);
        vm.stopPrank();
        vm.startPrank(FROM);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 0, 1);
        token.transferFrom(FROM, TO, NFT);

        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.currentVotes(OPERATOR), 1);
        assertEq(token.currentVotes(TO), 0);

        assertEq(token.totalCheckpoints(FROM), 2);
        (uint32 fromBlock, uint32 votes) = token.checkpoints(FROM, 1);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 0);

        assertEq(token.totalCheckpoints(OPERATOR), 1);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 0);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 1);

        // No checkpoints should be added to the receiver.
        assertEq(token.totalCheckpoints(TO), 0);

        vm.roll(BLOCK_START + 3);
        assertEq(token.priorVotes(FROM, BLOCK_START + 2), 0);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 2), 1);
        assertEq(token.priorVotes(TO, BLOCK_START + 2), 0);
    }

    function _testDelegateWithMultipleTransfers(function(address) external fn) public reset {
        token.mint(FROM, NFT_1);
        token.mint(FROM, NFT_2);
        vm.roll(BLOCK_START + 2);

        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 3, 2);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 0, 1);
        token.transferFrom(FROM, TO, NFT);

        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 2, 1);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 0, 1);
        token.transferFrom(FROM, OPERATOR, NFT_1);

        vm.roll(BLOCK_START + 3);

        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(FROM, FROM, TO);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(FROM, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 1, 2);
        fn(TO);

        vm.roll(BLOCK_START + 4);

        vm.stopPrank();
        vm.startPrank(TO);
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(TO, TO, OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 2, 1);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 1, 2);
        fn(OPERATOR);

        vm.roll(BLOCK_START + 5);
        vm.stopPrank();
        vm.startPrank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(OPERATOR, 2, 1);
        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(TO, 1, 2);
        token.transferFrom(OPERATOR, FROM, NFT_1);

        assertEq(token.currentVotes(FROM), 0);
        assertEq(token.currentVotes(OPERATOR), 1);
        assertEq(token.currentVotes(TO), 2);

        assertEq(token.totalCheckpoints(FROM), 4);
        (uint32 fromBlock, uint32 votes) = token.checkpoints(FROM, 1);
        assertEq(fromBlock, BLOCK_START + 1);
        assertEq(votes, 3);
        (fromBlock, votes) = token.checkpoints(FROM, 2);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(FROM, 3);
        assertEq(fromBlock, BLOCK_START + 3);
        assertEq(votes, 0);

        assertEq(token.totalCheckpoints(OPERATOR), 3);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 0);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 1);
        assertEq(fromBlock, BLOCK_START + 4);
        assertEq(votes, 2);
        (fromBlock, votes) = token.checkpoints(OPERATOR, 2);
        assertEq(fromBlock, BLOCK_START + 5);
        assertEq(votes, 1);

        assertEq(token.totalCheckpoints(TO), 4);
        (fromBlock, votes) = token.checkpoints(TO, 0);
        assertEq(fromBlock, BLOCK_START + 2);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(TO, 1);
        assertEq(fromBlock, BLOCK_START + 3);
        assertEq(votes, 2);
        (fromBlock, votes) = token.checkpoints(TO, 2);
        assertEq(fromBlock, BLOCK_START + 4);
        assertEq(votes, 1);
        (fromBlock, votes) = token.checkpoints(TO, 3);
        assertEq(fromBlock, BLOCK_START + 5);
        assertEq(votes, 2);

        vm.roll(BLOCK_START + 6);
        assertEq(token.priorVotes(FROM, BLOCK_START + 1), 3);
        assertEq(token.priorVotes(FROM, BLOCK_START + 2), 1);
        assertEq(token.priorVotes(FROM, BLOCK_START + 3), 0);
        assertEq(token.priorVotes(FROM, BLOCK_START + 4), 0);
        assertEq(token.priorVotes(FROM, BLOCK_START + 5), 0);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 2), 1);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 3), 1);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 4), 2);
        assertEq(token.priorVotes(OPERATOR, BLOCK_START + 5), 1);
        assertEq(token.priorVotes(TO, BLOCK_START + 1), 0);
        assertEq(token.priorVotes(TO, BLOCK_START + 2), 1);
        assertEq(token.priorVotes(TO, BLOCK_START + 3), 2);
        assertEq(token.priorVotes(TO, BLOCK_START + 4), 1);
        assertEq(token.priorVotes(TO, BLOCK_START + 5), 2);
    }

}
