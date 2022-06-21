# DθPΛM1NΞ

Dopamine DAO is a Nouns DAO fork modified to support "drops" of Dopamine tabs, ERC-721 NFTs with non-generative psychadelic art that act as the membership token to the Dopamine metaverse.

## Components

Dopamine contracts are currently divided into four components: Governance, ERC721, Auctions, and NFTs.

| Component                                                   | Description                                           |
| ------------------------------------------------------------|------------------------------------------------------ |
| [`@dopamine-contracts/governance`](/src/governance)         | Minimal Governor Bravo fork designed for ERC-721s     |
| [`@dopamine-contracts/erc721`](/src/erc721)                 | Gas-efficient ERC-721 with voting capabilities        |
| [`@dopamine-contracts/auctions`](/src/auctions)             | Simplified Nouns DAO Auction fork                     |
| [`@dopamine-contracts/nft`](/src/nft)                       | Dopamine membership drop coordination & ERC-721 NFTs  |

### License

[GPL-3.0](./LICENSE.md) © Dopamine Inc.


### Contract address(rinkeby)
dopamineTab: 0x4ee07a0a97c03e9e52b8c47e30cda07fc2f14709
dopamineAuctionHouse: 0x6f4c8853b262a24fe305148ac1632beed9b45a7c
dopamineAuctionHouseProxy: 0x798378c914c50531a5878cada442932148804048.
timeLock: 0xd698ddf629baed5160762ca76c1ef7808633c22f.
dopamineDao: 0xa741f5465ede12d0a840bce8d1102b6b6bf34ce6.
dopamineDAOProxy: 0x6b858afa4e31422b8fee272b449b6c802174962e.

### Script
| Deploy contract using script (staging)
source .env
forge script src/scripts/DeployStaging.sol -vvvv --fork-url https://eth-rinkeby.alchemyapi.io/v2/$ALCHEMY_API_KEY --private-key $DEV_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

| Deploy contract using script (production)
source .env
forge script src/scripts/DeployStaging.sol -vvvv --fork-url https://eth-mainnet.alchemyapi.io/v2/$ALCHEMY_API_KEY --private-key $DEV_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

| Run createDrop function
forge script src/scripts/CreateDropStaging.sol --sig "createFirstDrop()" -vvvv --fork-url https://eth-rinkeby.alchemyapi.io/v2/$ALCHEMY_API_KEY --private-key $DEV_PRIVATE_KEY --broadcast

### Forge Command
forge test --match-path src/test/LaunchTest.t.sol --ffi
forge test --match-path src/test/DopamineTab.t.sol --match-test testClaim --ffi -vv