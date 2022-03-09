interface IDopamintPassEvents {

	event Claimed(address indexed claimer, uint256 tokenId);

    event DropCreated(uint256 indexed dropId, uint256 startIndex, uint256 dropSize, bytes32 provenanceHash);

    event DropDelaySet(uint256 dropDelay);

    event DropSizeSet(uint256 dropSize);

    event MinterLocked();

    event NewMinter(address oldMinter, address newMinter);

}
