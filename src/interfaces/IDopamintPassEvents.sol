interface IDopamintPassEvents {

    event Burn(uint256 indexed tokenId);

	event Claimed(address indexed claimer);

    event DropCompleted(uint256 indexed dropId, uint256 endTime);

    event DropCreated(uint256 indexed dropId, uint256 startIndex, uint256 dropSize, uint256 startTime, string dropHash);

    event DropDelegate(address delegator, address delegatee, uint256 tokenId);

    event ChangeMinter(address minter);

    event LockMinter();

    event Mint(uint256 indexed tokenId);

    event NewDropDelay(uint256 dropDelay);

}
