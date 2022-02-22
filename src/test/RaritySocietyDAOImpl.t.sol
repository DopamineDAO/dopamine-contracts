// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./mocks/MockRaritySocietyDAOToken.sol";
import "./mocks/MockRaritySocietyDAOImpl.sol";
import "../interfaces/IRaritySocietyDAO.sol";

import "../governance/Timelock.sol";

import "./utils/test.sol";
import "./utils/console.sol";

/// @title ERC721 Test Suites
contract RaritySocietyDAOImplTest is Test {

    /// @notice Proposal function calldata.
    string constant SIGNATURE = "setDelay(uint256)";
    bytes constant CALLDATA = abi.encodePacked(uint256(TIMELOCK_DELAY + 1));
    address[] TARGETS = new address[](1);
    uint256[] VALUES = new uint256[](1);
    bytes[] CALLDATAS = new bytes[](1);
    string[] SIGNATURES = new string[](1);

    /// @notice Default governance voting parameters.
    uint256 constant TIMELOCK_DELAY = 60 * 60 * 24 * 3;
    uint256 constant TIMELOCK_TIMESTAMP = 9999;
    uint32 constant VOTING_PERIOD = 6400;
    uint32 constant VOTING_DELAY = 60;
    uint32 constant PROPOSAL_THRESHOLD = 1;
    uint32 constant QUORUM_THRESHOLD_BPS = 1500; // 15%
    uint256 TOTAL_SUPPLY = 20;

    /// @notice Block numbers for testing.
    uint256 BLOCK_START = 99; // Testing starts at this block.
    uint256 BLOCK_PROPOSAL = BLOCK_START + 1; // Proposals made at this block.
    // Proposals queued at this block.
    uint256 BLOCK_QUEUE = BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD + 1;


    /// @notice Addresses used for testing.
    address constant VETOER = address(12629);
    address FROM; // Generated using private key `PK_FROM`.
    address ADMIN; // Generated using private key `PK_ADMIN`.

    /// @notice Private keys (primarily used for `castVoteBySig` testing).
    uint256 constant PK_FROM = 1;
    uint256 constant PK_ADMIN = 2;
    uint256[2] PKS = [PK_FROM, PK_ADMIN];

    /// @notice Core governance contracts used for testing.
    MockRaritySocietyDAOToken token;
    Timelock timelock;
    MockRaritySocietyDAOImpl dao;

    /// @notice Rarity Society DAO events.
    event ProposalCreated(
        uint32 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint32 startBlock,
        uint32 endBlock,
        uint32 quorumThreshold,
        string description
    );

    event VoteCast(address indexed voter, uint32 proposalId, uint8 support, uint32 votes);

    event ProposalCanceled(uint32 id);

    event ProposalQueued(uint32 id, uint256 eta);

    event ProposalExecuted(uint32 id);

    event ProposalVetoed(uint32 id);

    event VotingDelaySet(uint32 votingDelay);

    event VotingPeriodSet(uint32 votingPeriod);

    event ProposalThresholdSet(uint32 proposalThreshold);

    event QuorumThresholdBPSSet(uint256 quorumThresholdBPS);

    event NewPendingAdmin(address pendingAdmin);

    event NewAdmin(address oldAdmin, address newAdmin);

    event NewVetoer(address vetoer);

    /// @notice Start test with initialized proposal.
    modifier proposalCreated {
        token.batchMint(TOTAL_SUPPLY); // Allocates 20 gov tokens to `ADMIN`.
        vm.roll(BLOCK_PROPOSAL);
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
        _;
    }

    /// @dev Start testing with initialized gov contract and signers.
    function setUp() public {
        vm.roll(BLOCK_START);

        FROM = vm.addr(PK_FROM);
        ADMIN = vm.addr(PK_ADMIN);
        vm.startPrank(ADMIN);

        token = new MockRaritySocietyDAOToken(ADMIN, 99);
        timelock = new Timelock(
            getContractAddress(address(ADMIN), 0x02), // DAO address (nonce = 2)
            TIMELOCK_DELAY
        );
        dao = new MockRaritySocietyDAOImpl(PKS);

        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );

        /// @notice Initialize proposal function calldata.
        TARGETS[0] = address(timelock);
        VALUES[0] = 0;
        SIGNATURES[0] = SIGNATURE;
        CALLDATAS[0] = CALLDATA;
    }

    /// @notice Test initialization functionality.
    function testInitialize() public {
        /// Reverts when setting invalid voting period.
        dao = new MockRaritySocietyDAOImpl(PKS);
        uint32 invalidParam = dao.MIN_VOTING_PERIOD() - 1;
        expectRevert("InvalidVotingPeriod()");
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            invalidParam,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );

        /// Reverts when setting invalid voting delay.
        invalidParam = dao.MAX_VOTING_DELAY() + 1;
        expectRevert("InvalidVotingDelay()");
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            invalidParam,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );

        /// Reverts when setting invalid proposal threshold.
        invalidParam = dao.MIN_PROPOSAL_THRESHOLD() - 1;
        expectRevert("InvalidProposalThreshold()");
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            invalidParam,
            QUORUM_THRESHOLD_BPS
        );

        /// Reverts when setting invalid quorum threshold bips.
        invalidParam = dao.MIN_QUORUM_THRESHOLD_BPS() - 1;
        expectRevert("InvalidQuorumThreshold()");
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            invalidParam
        );

        /// Correctly sets all governance parameters.
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.votingDelay(), VOTING_DELAY);
        assertEq(dao.quorumThresholdBPS(), QUORUM_THRESHOLD_BPS);
        assertEq(address(dao.timelock()), address(timelock));
        assertEq(dao.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(dao.proposalId(), 0);
        assertEq(address(dao.vetoer()), VETOER);
        assertEq(address(dao.token()), address(token));
        assertEq(address(dao.admin()), ADMIN);
        assertEq(address(dao.pendingAdmin()), address(0));

        /// Reverts when trying to initialize more than once.
        expectRevert("AlreadyInitialized()");
        dao.initialize(
            address(timelock),
            address(token),
            VETOER,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD_BPS
        );
    }

    /// @notice Test `setVotingPeriod` functionality.
    function testSetVotingPeriod() public {
        // Reverts when voting period is too small.
        uint32 minPeriod = dao.MIN_VOTING_PERIOD();
        expectRevert("InvalidVotingPeriod()");
        dao.setVotingPeriod(minPeriod - 1);

        // Reverts when voting period is too large.
        uint32 maxPeriod = dao.MAX_VOTING_PERIOD();
        expectRevert("InvalidVotingPeriod()");
        dao.setVotingPeriod(maxPeriod + 1);

        // Emits expected `VotingPeriodSet` event.
        vm.expectEmit(true, true, true, true);
        emit VotingPeriodSet(VOTING_PERIOD);
        dao.setVotingPeriod(VOTING_PERIOD);

        // Properly sets `votingPeriod`.
        assertEq(dao.votingPeriod(), VOTING_PERIOD);

        // Reverts when not set by the admin.
        vm.startPrank(FROM);
        expectRevert("AdminOnly()");
        dao.setVotingPeriod(VOTING_PERIOD - 1);

    }

    /// @notice Test `setVotingDelay` functionality.
    function testSetVotingDelay() public {
        // Reverts when voting delay too small.
        uint32 minDelay = dao.MIN_VOTING_DELAY();
        expectRevert("InvalidVotingDelay()");
        dao.setVotingDelay(minDelay - 1);

        // Reverts when voting delay too large.
        uint32 maxDelay = dao.MAX_VOTING_DELAY();
        expectRevert("InvalidVotingDelay()");
        dao.setVotingDelay(maxDelay + 1);

        // Emits the expected `VotingDelaySet` event.
        vm.expectEmit(true, true, true, true);
        emit VotingDelaySet(VOTING_DELAY);
        dao.setVotingDelay(VOTING_DELAY);

        // Properly assigns voting delay.
        assertEq(dao.votingDelay(), VOTING_DELAY);

        // Reverts when not set by the admin.
        vm.startPrank(FROM);
        expectRevert("AdminOnly()");
        dao.setVotingDelay(VOTING_DELAY - 1);

    }

    /// @notice Test `setProposalThreshold` functionality.
    function testSetProposalThreshold() public {
        // Reverts when proposal threshold too low.
        uint32 minProposalThreshold = dao.MIN_PROPOSAL_THRESHOLD();
        expectRevert("InvalidProposalThreshold()");
        dao.setProposalThreshold(minProposalThreshold - 1);

        // Reverts when proposal threshold too high.
        uint32 maxProposalThreshold = dao.MAX_PROPOSAL_THRESHOLD();
        expectRevert("InvalidProposalThreshold()");
        dao.setProposalThreshold(maxProposalThreshold + 1);

        // When token supply is 0, min & max proposal threshold is 1.
        assertEq(minProposalThreshold, maxProposalThreshold);
        assertEq(minProposalThreshold, 1);

        // When DAO token supply is 19, proposal threshold still capped at 1.
        token.batchMint(19);
        expectRevert("InvalidProposalThreshold()");
        dao.setProposalThreshold(minProposalThreshold + 1);

        // At DAO token supply of 20, proposal threshold no longer capped at 1.
        token.mint();
        dao.setProposalThreshold(minProposalThreshold + 1);

        // Emits the expected `ProposalThresholdSet` event.
        vm.expectEmit(true, true, true, true);
        emit ProposalThresholdSet(PROPOSAL_THRESHOLD);
        dao.setProposalThreshold(PROPOSAL_THRESHOLD);

        // Properly assigns proposal threshold.
        assertEq(dao.proposalThreshold(), PROPOSAL_THRESHOLD);

        // Reverts when not set by the admin.
        vm.startPrank(FROM);
        expectRevert("AdminOnly()");
        dao.setProposalThreshold(PROPOSAL_THRESHOLD - 1);

    }

    /// @notice Test `setQuorumThresholdBPS` functionality.
    function testSetQuorumThresholdBPS() public {
        // Reverts when quorum threshold bips is too low.
        uint32 minQuorumThresholdBPS = dao.MIN_QUORUM_THRESHOLD_BPS();
        expectRevert("InvalidQuorumThreshold()");
        dao.setQuorumThresholdBPS(minQuorumThresholdBPS - 1);

        // Reverts when quorum threshold bips is too high.
        uint32 maxQuorumThresholdBPS = dao.MAX_QUORUM_THRESHOLD_BPS();
        expectRevert("InvalidQuorumThreshold()");
        dao.setQuorumThresholdBPS(maxQuorumThresholdBPS + 1);

        // Emits the expected `QuorumThresholdBPSSet` event.
        vm.expectEmit(true, true, true, true);
        emit QuorumThresholdBPSSet(QUORUM_THRESHOLD_BPS);
        dao.setQuorumThresholdBPS(QUORUM_THRESHOLD_BPS);

        // Properly assigns quorum threshold bips.
        assertEq(dao.quorumThresholdBPS(), QUORUM_THRESHOLD_BPS);

        // Reverts when not set by the admin.
        vm.startPrank(FROM);
        expectRevert("AdminOnly()");
        dao.setQuorumThresholdBPS(QUORUM_THRESHOLD_BPS - 1);
    }
    
    /// @notice Test `setSetPendingAdmin` functionality.
    function testSetPendingAdmin() public {
        // When unset, pending admin should be the zero address.
        assertEq(dao.pendingAdmin(), address(0));

        // Emits the expected `NewPendingAdmin` event.
        vm.expectEmit(true, true, true, true);
        emit NewPendingAdmin(FROM);
        dao.setPendingAdmin(FROM);

        // Properly assigns pending admin.
        assertEq(dao.pendingAdmin(), FROM);

        // Reverts when not set by the admin.
        vm.prank(FROM);
        expectRevert("AdminOnly()");
        dao.setPendingAdmin(FROM);
    }

    /// @notice Tests `acceptAdmin` functionality.
    function testAcceptAdmin() public {
        // Reverts when caller is not the pending admin.
        dao.setPendingAdmin(FROM);
        expectRevert("PendingAdminOnly()");
        dao.acceptAdmin(); // Still called by current admin, hence fails..

        // Emits the expected `NewAdmin` event when executed by pending admin.
        vm.startPrank(FROM);
        vm.expectEmit(true, true, true, true);
        emit NewAdmin(ADMIN, FROM);
        dao.acceptAdmin();

        // Properly assigns admin and clears pending admin.
        assertEq(dao.admin(), FROM);
        assertEq(dao.pendingAdmin(), address(0));
    }

    /// @notice Tests `setVetoer` functionality.
    function testSetVetoer() public {
        // Reverts when not called by the vetoer.
        vm.startPrank(FROM);
        expectRevert("VetoerOnly()");
        dao.setVetoer(FROM);

        // Emits the expected `NewVetoer` event when executed by the vetoer.
        vm.startPrank(VETOER);
        vm.expectEmit(true, true, true, true);
        emit NewVetoer(FROM);
        dao.setVetoer(FROM);

        // Properly assigns vetoer.
        assertEq(dao.vetoer(), FROM);
    }
    
    /// @notice Test `propose` functionality.
    function testPropose() public {
        // Reverts when proposing with 0 tokens allocated.
        expectRevert("InsufficientVotingPower()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");

        // Grant 19 gov tokens to `FROM`, 1 gov token to `FROM`.
        token.batchMint(TOTAL_SUPPLY); // Allocates 20 gov tokens to `ADMIN`.
        token.transferFrom(ADMIN, FROM, 0); // Transfer 1 gov token to `FROM`.

        // Set proposal threshold to max relative to total supply.
        uint32 maxProposalThreshold = dao.MAX_PROPOSAL_THRESHOLD();
        assertEq(maxProposalThreshold, 2); // 10% of 20 = 2.
        dao.setProposalThreshold(maxProposalThreshold);

        // Reverts when proposing under proposal threshold.
        vm.startPrank(FROM); // Threshold is 2, but `FROM` only has 1.
        expectRevert("InsufficientVotingPower()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");

        // Transfer 1 more token to `FROM` to meet proposal threshold of 2.
        vm.startPrank(ADMIN);
        token.transferFrom(ADMIN, FROM, 1);
        vm.startPrank(FROM);
        vm.roll(BLOCK_PROPOSAL);

        // Reverts when there's an input arity mismatch.
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);
        string[] memory signatures = new string[](0);
        expectRevert("ArityMismatch()");
        dao.propose(targets, VALUES, SIGNATURES, CALLDATAS, "");
        expectRevert("ArityMismatch()");
        dao.propose(TARGETS, values, SIGNATURES, CALLDATAS, "");
        expectRevert("ArityMismatch()");
        dao.propose(TARGETS, VALUES, signatures, CALLDATAS, "");
        expectRevert("ArityMismatch()");
        dao.propose(TARGETS, VALUES, SIGNATURES, calldatas, "");
        
        // Reverts when an invalid number of actions are provided (0).
        expectRevert("InvalidActionCount()");
        dao.propose(targets, values, signatures, calldatas, "");

        // Emits the expected `ProposalCreated` event.
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            1,
            FROM,
            TARGETS,
            VALUES,
            SIGNATURES,
            CALLDATAS,
            uint32(BLOCK_PROPOSAL + VOTING_DELAY),
            uint32(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD),
            3, // Quorum threshold = 15% of 20.
            ""
        );
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");

        // Properly assigns all proposal attributes.
        IRaritySocietyDAO.Proposal memory proposal = dao.getProposal();
        assertEq(proposal.id, 1);
        assertEq(proposal.proposer, FROM);
        assertEq(proposal.quorumThreshold, 3);
        assertEq(proposal.eta, 0);
        assertEq(proposal.startBlock, BLOCK_PROPOSAL + VOTING_DELAY);
        assertEq(proposal.endBlock, BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        assertEq(proposal.forVotes, 0);
        assertEq(proposal.againstVotes, 0);
        assertEq(proposal.abstainVotes, 0);
        assertTrue(!proposal.vetoed);
        assertTrue(!proposal.canceled);
        assertTrue(!proposal.executed);
        (address[] memory t, uint256[] memory v, string[] memory s, bytes[] memory c) = dao.getActions();
        assertEq(t, TARGETS);
        assertEq(v, VALUES);
        assertEq(s, SIGNATURES);
        assertEq(c, CALLDATAS);

        // Reverts when propsing while an unsettled proposal exists.
        expectRevert("UnsettledProposal()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    
    function testCastVote() public {
        _testVoteBehavior(dao.castVote);
    }

    function testCastVoteBySig() public {
        _testVoteBehavior(dao.mockCastVoteBySig);
    }

    function testSecurityCastVoteBySig() proposalCreated public {
        vm.roll(BLOCK_START + 1 + VOTING_DELAY);
        bytes32 domainSeparator =
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Rarity Society DAO"),
                    keccak256("1"),
                    block.chainid,
                    address(dao)
                )
            );
        bytes32 structHash = 
            keccak256(
                abi.encode(
                    keccak256("Vote(address voter,uint256 proposalId,uint8 support)"),
                    FROM,
                    dao.proposalId(),
                    0
                )
            );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 a, bytes32 b, bytes32 c) = vm.sign(PK_ADMIN, hash);

        // Reverts if not signed by the voter themself.
        expectRevert("InvalidSignature()");
        dao.castVoteBySig(FROM, 0, a, b, c);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK_FROM, hash);

        // Reverts if mismatching voting type is used.
        expectRevert("InvalidSignature()");
        dao.castVoteBySig(FROM, 1, v, r, s);

        // Works otherwise.
        dao.castVoteBySig(FROM, 0, v, r, s);

        // Replay attacks are prevented.
        expectRevert("AlreadyVoted()");
        dao.castVoteBySig(FROM, 0, v, r, s);
    }

    /// @notice Tests internal voting behavior.
    function _testVoteBehavior(function(uint8) external fn) proposalCreated internal {
        // Transfer 2 gov voting tokens to `FROM`.
        token.transferFrom(ADMIN, FROM, 0);
        token.transferFrom(ADMIN, FROM, 1);

        // Throws when voting for inactive proposal.
        expectRevert("InactiveProposal()");
        fn(0);

        // These 2 transfers should have no effect on `FROM` 1st proposal voting
        // weight, because weights are based on time of `BLOCK_PROPOSAL`.
        vm.roll(BLOCK_PROPOSAL + 1); 
        token.transferFrom(ADMIN, FROM, 2);
        token.transferFrom(ADMIN, FROM, 3);

        vm.startPrank(FROM); // Vote as `FROM`.

        // Throws while proposal is still pending.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY - 1);
        expectRevert("InactiveProposal()");
        fn(0);

        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY); // Ensures proposal active.

        // Throws when vote type is not valid.
        expectRevert("InvalidVote()");
        fn(3);

        // Emits `VoteCast` event with parameters.
        vm.expectEmit(true, true, true, true);
		emit VoteCast(FROM, 1, 0, 2);
        fn(0);
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
		emit VoteCast(ADMIN, 1, 2, 18);
        fn(2);

        // Ensure all voting receipts are as expected.
        (uint32 idFrom, uint8 supportFrom, uint32 votesFrom) = dao.receipts(FROM);
        assertEq(idFrom, 1);
        assertEq(supportFrom, 0);
        assertEq(votesFrom, 2);
        (uint32 idAdmin, uint8 supportAdmin, uint32 votesAdmin) = dao.receipts(ADMIN);
        assertEq(idAdmin, 1);
        assertEq(supportAdmin, 2);
        assertEq(votesAdmin, 18);

        // Move to last block where voting is still considered active.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);

        // Throws if voting on the same proposal.
        expectRevert("AlreadyVoted()");
        fn(0);

        // Throws when proposal voting period is closed.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD + 1);
        expectRevert("InactiveProposal()");
        fn(0);
    }

    /// @notice Tests expected behavior during pending proposal phase.
    function testLifecycleStatePending() proposalCreated public {
        // Upon proposal creation, state is pending.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Pending));

        // Before the proposal starting block, state remains pending.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY - 1);
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Pending));

        // Ensure new proposals cannot be made while pending.
        expectRevert("UnsettledProposal()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Tests expected behavior during active proposal phase.
    function testLifecycleStateActive() proposalCreated public {

        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY); // Move to active phase.

        // State should be marked active.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Active));

        // On proposal end block, state remains active.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Active));

        // Ensure new proposals cannot be made while active.
        expectRevert("UnsettledProposal()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Tests expected behavior during successful proposal phase.
    function testLifecycleStateSucceeded() proposalCreated public {
        // Expected quorum threshold = MIN_QUORUM_THRESHOLD (15%) * 20 = 3.
        IRaritySocietyDAO.Proposal memory proposal = dao.getProposal();
        assertEq(proposal.quorumThreshold, 3);

        // Transfer 3 tokens from `ADMIN` to `FROM` to hit quorum threshold.
        token.transferFrom(ADMIN, FROM, 0);
        token.transferFrom(ADMIN, FROM, 1);
        token.transferFrom(ADMIN, FROM, 2);
        
        // Move to active voting phase.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);

        // Vote in support of proposal as `FROM` and hit vote quorum threshold.
        vm.startPrank(FROM);
        dao.castVote(1);

        // Move past voting phase.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD + 1);
        
        // Check that state is now succeeded.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Succeeded));

        // Ensure new proposals cannot be made while in state of successful.
        expectRevert("UnsettledProposal()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Tests expected behavior during defeated proposal phase.
    function testLifecycleStateDefeated() proposalCreated public {
        // Move past voting phase.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD + 1);
        
        // Check that state is now defeated.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Defeated));

        // Ensure a new proposal can be made once marked defeated.
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Test expected behavior during queued proposal phase.
    function testLifecycleStateQueued() proposalCreated public {
        // Unsuccessful proposals should not be queueable.
        expectRevert("UnpassedProposal()");
        dao.queue();

        // Ensure proposal is successful.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE);
        vm.warp(TIMELOCK_TIMESTAMP);


        // Emits `ProposalQueued` event when `queue` is called successfully.
        vm.expectEmit(true, true, true, true);
		emit ProposalQueued(1, TIMELOCK_TIMESTAMP + TIMELOCK_DELAY);
        dao.queue();

        // Assert state is now queued.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Queued));

        // `eta` changes as expected.
        IRaritySocietyDAO.Proposal memory proposal = dao.getProposal();
        assertEq(proposal.eta, TIMELOCK_TIMESTAMP + TIMELOCK_DELAY);


        // Ensure new proposals cannot be made while queued.
        expectRevert("UnsettledProposal()");
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");

        // Submit another proposal with duplicate transactions.
        dao.cancel();
        TARGETS.push(address(timelock));
        VALUES.push(0);
        SIGNATURES.push(SIGNATURE);
        CALLDATAS.push(CALLDATA);
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
        vm.roll(BLOCK_QUEUE + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE + VOTING_DELAY + VOTING_PERIOD + 1);

        // Expect revert due to duplicate transaction.
        expectRevert("DuplicateTransaction()");
        dao.queue();
    }

    /// @notice Test expected behavior during execution proposal phase.
    function testLifecycleStateExecuted() proposalCreated public {
        // Unqueued proposals cannot be executed.
        expectRevert("UnqueuedProposal()");
        dao.execute();

        // Ensure proposal is successful.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE);
        vm.warp(TIMELOCK_TIMESTAMP);
        dao.queue();

        // Reverts if executed before timelock delay passed.
        expectRevert("PrematureTx()");
        dao.execute();

        vm.warp(TIMELOCK_TIMESTAMP + TIMELOCK_DELAY); // Fast-forward to eta.

        // Check tx has not yet executed.
        assertEq(timelock.delay(), TIMELOCK_DELAY);

        // Check expected `ProposalExecuted` event emitted.
        vm.expectEmit(true, true, true, true);
        emit ProposalExecuted(1);
        dao.execute();

        // Assert state is now executed.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Executed));

        // Verify transaction did in fact execute (`setDelay`).
        assertEq(timelock.delay(), TIMELOCK_DELAY + 1);

        // Proposal cannot be canceled.
        expectRevert("AlreadySettled()");
        dao.cancel();

        // Proposal also cannot be vetoed.
        vm.startPrank(VETOER);
        expectRevert("AlreadySettled()");
        dao.cancel();

        // New proposals can now be made.
        vm.startPrank(ADMIN);
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Test expected behavior during canceled proposal phase.
    function testLifecycleStateCanceled() proposalCreated public {
        // Move to block at which proposal queued.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE);
        dao.queue();

        // Reverts if not canceled by the proposer.
        vm.startPrank(FROM);
        expectRevert("ProposerOnly()");
        dao.cancel();

        // Successfully cancels proposal and emits `ProposalCanceled` event.
        vm.startPrank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ProposalCanceled(1);
        dao.cancel();

        // Assert state is now canceled.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Canceled));

        // Execution of the proposal will now fail.
        expectRevert("UnqueuedProposal()");
        dao.execute();

        // New proposals can now be made.
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }

    /// @notice Test expected behavior during veto proposal phase.
    function testLifecycleStateVetoed() proposalCreated public {
        // Move to block at which proposal queued.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE);
        dao.queue();

        // Reverts if not vetoed by vetoer.
        vm.startPrank(FROM);
        expectRevert("VetoerOnly()");
        dao.veto();

        // Successfully cancels proposal and emits `ProposalVetoedd` event.
        vm.startPrank(VETOER);
        vm.expectEmit(true, true, true, true);
        emit ProposalVetoed(1);
        dao.veto();

        // Assert state is now vetoed.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Vetoed));

        // Execution of the proposal will now fail.
        expectRevert("UnqueuedProposal()");
        dao.execute();

        // Revoke veto power by setting vetoer to zero address.
        dao.setVetoer(address(0));

        // New proposals can now be made.
        vm.startPrank(ADMIN);
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");

        // Vetoing now fails since power was revoked.
        expectRevert("VetoPowerRevoked()");
        dao.veto();
    }

    /// @notice Test expected behavior during expired proposal phase.
    function testLifecycleStateExpired() proposalCreated public {
        // Move to block at which proposal queued.
        vm.roll(BLOCK_PROPOSAL + VOTING_DELAY + VOTING_PERIOD);
        dao.castVote(1);
        vm.roll(BLOCK_QUEUE);
        vm.warp(TIMELOCK_TIMESTAMP);

        // Queue transaction.
        dao.queue();

        // Move to earliest time at which transaction is considered stale.
        vm.warp(TIMELOCK_TIMESTAMP + TIMELOCK_DELAY + timelock.GRACE_PERIOD() + 1); // Fast-forward to eta.

        // Assert state is now expired.
        assertEq(uint256(dao.state()), uint256(IRaritySocietyDAO.ProposalState.Expired));

        // Execution should no longer work.
        expectRevert("UnqueuedProposal()");
        dao.execute();

        // New proposals can now be made.
        dao.propose(TARGETS, VALUES, SIGNATURES, CALLDATAS, "");
    }
}
