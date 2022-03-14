interface IDopamintPassEvents {

    event DropCreated(uint256 indexed dropId, uint256 startIndex, uint256 dropSize, uint256 whitelistSize, bytes32 whitelist, bytes32 provenanceHash);

    event DropDelaySet(uint256 dropDelay);

    event DropSizeSet(uint256 dropSize);

    event WhitelistSizeSet(uint256 whitelistSize);

    event MinterLocked();

    event NewMinter(address oldMinter, address newMinter);

}
