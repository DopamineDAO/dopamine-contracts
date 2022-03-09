// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

////////////////////////////////////////////////////////////////////////////////
///                               DOPAMINTPASS                               /// 
////////////////////////////////////////////////////////////////////////////////

/// @notice DopamintPass drop hit allocated capacity.
error DropMaxCapacity();

/// @notice Insufficient time passed since last drop was created.
error InsufficientTimePassed();

/// @notice Configured drop delay is invalid.
error InvalidDropDelay();

/// @notice COnfigured drop size is invalid.
error InvalidDropSize();

/// @notice Action cannot be completed as a current drop is ongoing.
error OngoingDrop();

/// @notice No such drop exists.
error NonexistentDrop();



//////////////////////////////////////////////////////////////////////////////// 
///                                   MISC                                   ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Number does not fit in 32 bytes.
error InvalidUint32();

/// @notice Block number being queried is invalid.
error InvalidBlock();

/// @notice Mismatch between input arrays.
error ArityMismatch();

////////////////////////////////////////////////////////////////////////////////
///                                 UPGRADES                                 ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Contract already initialized.
error AlreadyInitialized();

/// @notice Upgrade requires either admin or vetoer privileges.
error UnauthorizedUpgrade();

////////////////////////////////////////////////////////////////////////////////
///                                 EIP-712                                  ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Signature has expired and is no longer valid.
error ExpiredSignature();

/// @notice Signature invalid.
error InvalidSignature();

////////////////////////////////////////////////////////////////////////////////
///                                 ERC-721                                  ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Token has already minted.
error DuplicateMint();

/// @notice Originating address does not own the NFT.
error InvalidOwner();

/// @notice Receiving contract does not implement the ERC721 wallet interface.
error InvalidReceiver();

/// @notice Receiving address cannot be the zero address.
error ZeroAddressReceiver();

/// @notice NFT does not exist.
error NonExistentNFT();

/// @notice NFT collection has hit maximum supply capacity.
error SupplyMaxCapacity();

/// @notice Sender is not NFT owner, approved address, or owner operator.
error UnauthorizedSender();

////////////////////////////////////////////////////////////////////////////////
///                              ADMINISTRATIVE                              ///
////////////////////////////////////////////////////////////////////////////////
 
/// @notice Function callable only by the admin.
error AdminOnly();

/// @notice Function callable only by the minter.
error MinterOnly();

/// @notice Function callable only by the owner.
error OwnerOnly();

/// @notice Function callable only by the pending owner.
error PendingAdminOnly();

////////////////////////////////////////////////////////////////////////////////
///                                GOVERNANCE                                ///
//////////////////////////////////////////////////////////////////////////////// 

/// @notice Proposal has already been settled.
error AlreadySettled();

/// @notice Proposal already voted for.
error AlreadyVoted();

/// @notice Duplicate transaction queued.
error DuplicateTransaction();

/// @notice Voting power insufficient.
error InsufficientVotingPower();

/// @notice Invalid number of actions proposed.
error InvalidActionCount();

/// @notice Invalid set timelock delay.
error InvalidDelay();

/// @notice Proposal threshold is invalid.
error InvalidProposalThreshold();

/// @notice Quorum threshold is invalid.
error InvalidQuorumThreshold();

/// @notice Vote type is not valid.
error InvalidVote();

/// @notice Voting delay set is invalid.
error InvalidVotingDelay();

/// @notice Voting period set is invalid.
error InvalidVotingPeriod();

/// @notice Only the proposer may invoke this action.
error ProposerOnly();

/// @notice Transaction executed prematurely.
error PrematureTx();

/// @notice Transaction execution was reverted.
error RevertedTx();

/// @notice Transaction is stale.
error StaleTx();

/// @notice Inactive proposals may not be voted for.
error InactiveProposal();

/// @notice Function callable only by the timelock itself.
error TimelockOnly();

/// @notice Proposal has failed to or has yet to be successful.
error UnpassedProposal();

/// @notice Proposal has failed to or has yet to be queued.
error UnqueuedProposal();

/// @notice Transaction is not yet queued.
error UnqueuedTx();

/// @notice A proposal is currently running and must be settled first.
error UnsettledProposal();

/// @notice Function callable only by the vetoer.
error VetoerOnly();

/// @notice Veto power has been revoked.
error VetoPowerRevoked();

////////////////////////////////////////////////////////////////////////////////
///                             Merkle Whitelist                             /// 
////////////////////////////////////////////////////////////////////////////////

/// @notice Whitelisted NFT already claimed.
error AlreadyClaimed();

/// @notice Proof for claim is invalid.
error InvalidProof();
