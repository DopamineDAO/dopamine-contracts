import { Signer } from "@ethersproject/abstract-signer";
import { RarityPass, IWETH, GasBurner, MockWETH, MockERC721Token, MockERC1155Token, RaritySocietyDAOImpl, RaritySocietyDAOProxy, RaritySocietyAuctionHouse, RaritySocietyProxyAdmin, Timelock, IProxyRegistry } from "../../typechain";
export declare type RaritySocietyDAOProxyFixture = {
    token: MockERC721Token;
    timelock: Timelock;
    dao: RaritySocietyDAOProxy;
    daoProxyImpl: RaritySocietyDAOImpl;
    daoImpl: RaritySocietyDAOImpl;
    proxyAdmin: RaritySocietyProxyAdmin;
};
export declare type RaritySocietyDAOImplFixture = {
    token: MockERC721Token;
    timelock: Timelock;
    daoImpl: RaritySocietyDAOImpl;
};
export declare type RaritySocietyTokenFixture = {
    token: RarityPass;
    registry: IProxyRegistry;
};
export declare type RaritySocietyAuctionHouseFixture = {
    token: MockERC721Token;
    weth: IWETH;
    auctionHouse: RaritySocietyAuctionHouse;
};
export declare function wethFixture(signers: Signer[]): Promise<MockWETH>;
export declare function raritySocietyAuctionHouseFixture(signers: Signer[]): Promise<RaritySocietyAuctionHouseFixture>;
export declare function erc1155TokenFixture(signers: Signer[]): Promise<MockERC1155Token>;
export declare function erc721TokenFixture(signers: Signer[]): Promise<MockERC721Token>;
export declare function timelockFixture(signers: Signer[]): Promise<Timelock>;
export declare function gasBurnerFixture(signers: Signer[]): Promise<GasBurner>;
export declare function raritySocietyDAOImplFixture(signers: Signer[]): Promise<RaritySocietyDAOImplFixture>;
export declare function raritySocietyDAOProxyFixture(signers: Signer[]): Promise<RaritySocietyDAOProxyFixture>;
