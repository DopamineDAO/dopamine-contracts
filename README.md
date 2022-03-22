# DθPΛM1NΞ

Dopamine DAO is a Nouns DAO fork modified to support "drops" of Dopamine passes, ERC-721 NFTs with non-generative cyberpunk art that act as the membership token to the Dopamine DAO and gateway to the Dopamine metaverse.

## Components

Dopamine DAO contracts are currently divided into four components: Governance, ERC721, Auctions, and DopamintPass.

| Component                                                   | Description                                           |
| ------------------------------------------------------------|------------------------------------------------------ |
| [`@dopamine-contracts/governance`](/src/governance)         | Minimal Governor Bravo fork designed for ERC-721s     |
| [`@dopamine-contracts/erc721`](/src/erc721)                 | Gas-efficient ERC-721 with voting capabilities        |
| [`@dopamine-contracts/auctions`](/src/auctions)             | Simplified Nouns DAO Auction fork                     |
| [`@dopamine-contracts/DopamintPass`](/src/DopamintPass.sol) | Dopamine membership drop coordination and ERC-721 NFT |

### License

[GPL-3.0](./LICENSE.md) © Dopamine Inc.
* DopamineAuctionHouse.sol - English Auctions contract with emissions schedule
* DopamintPass.sol - ERC721 using ERC721Checkpointable for voting with drop emissions integration
