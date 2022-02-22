import { Signer } from "@ethersproject/abstract-signer";
import { ethers } from "hardhat";
import { getContractAddress } from "@ethersproject/address";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Constants } from "./constants";
import {
  RarityPass,
  RarityPass__factory,
	IWETH,
	IRaritySocietyDAOToken,
	MockWETH__factory,
	GasBurner,
	GasBurner__factory,
	MockWETH,
  MockERC721Token__factory,
  MockERC721Token,
  MockERC1155Token__factory,
  MockERC1155Token,
  RaritySocietyDAOImpl__factory,
  RaritySocietyDAOImpl,
	IRaritySocietyDAOToken__factory,
  RaritySocietyDAOProxy__factory,
  RaritySocietyDAOProxy,
	RaritySocietyAuctionHouse,
	RaritySocietyProxyAdmin,
	RaritySocietyProxyAdmin__factory,
	RaritySocietyAuctionHouse__factory,
  Timelock,
  Timelock__factory,
  IProxyRegistry,
  MockProxyRegistry__factory,
} from "../../typechain";

export type RaritySocietyDAOProxyFixture = {
  token: MockERC721Token;
  timelock: Timelock;
  dao: RaritySocietyDAOProxy;
  daoProxyImpl: RaritySocietyDAOImpl;
  daoImpl: RaritySocietyDAOImpl;
	proxyAdmin: RaritySocietyProxyAdmin;
};

export type RaritySocietyDAOImplFixture = {
  token: MockERC721Token;
  timelock: Timelock;
  daoImpl: RaritySocietyDAOImpl;
};

export type RaritySocietyTokenFixture = {
  token: RarityPass;
  registry: IProxyRegistry;
};

export type RaritySocietyAuctionHouseFixture  = {
  token: MockERC721Token;
  weth: IWETH;
	auctionHouse: RaritySocietyAuctionHouse;
};

export async function wethFixture(
	signers: Signer[]
): Promise<MockWETH> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const tokenFactory = new MockWETH__factory(deployer);
  const token = await tokenFactory.deploy();
	return token;
}

export async function raritySocietyAuctionHouseFixture(
  signers: Signer[]
): Promise<RaritySocietyAuctionHouseFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
	const weth = await wethFixture(signers);
  const auctionHouseFactory = new RaritySocietyAuctionHouse__factory(deployer);
  const auctionHouse = await auctionHouseFactory.deploy();
  const tokenFactory = new MockERC721Token__factory(deployer);
  const token = await tokenFactory.deploy(auctionHouse.address, 10);
  return { weth, token, auctionHouse };
}

export async function erc1155TokenFixture(
  signers: Signer[]
): Promise<MockERC1155Token> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const tokenFactory = new MockERC1155Token__factory(deployer);
  const token = await tokenFactory.deploy(deployer.address, 10);
  return token;
}
export async function erc721TokenFixture(
  signers: Signer[]
): Promise<MockERC721Token> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const tokenFactory = new MockERC721Token__factory(deployer);
  const token = await tokenFactory.deploy(deployer.address, 10);
  return token;
}

export async function timelockFixture(signers: Signer[]): Promise<Timelock> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const timelockFactory = new Timelock__factory(deployer);
  return await timelockFactory.deploy(
    deployer.address,
    Constants.TIMELOCK_DELAY
  );
}

export async function gasBurnerFixture(
	signers: Signer[]
): Promise<GasBurner> {
	const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
	const gasBurnerFactory = new GasBurner__factory(deployer);
	return await gasBurnerFactory.deploy();
}

export async function raritySocietyDAOImplFixture(
  signers: Signer[]
): Promise<RaritySocietyDAOImplFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const admin: SignerWithAddress = signers[1] as SignerWithAddress;
  const vetoer: SignerWithAddress = signers[2] as SignerWithAddress;
  const tokenFactory = new MockERC721Token__factory(deployer);
  const token = await tokenFactory.deploy(deployer.address, 99);
  // 2nd TX MUST be daoImpl deployment
  const daoImplAddress = getContractAddress({
    from: deployer.address,
    nonce: (await deployer.getTransactionCount()) + 1,
  });
  const timelockFactory = new Timelock__factory(deployer);
  const timelock = await timelockFactory.deploy(
    daoImplAddress,
    Constants.TIMELOCK_DELAY
  );
  const daoImplFactory = new RaritySocietyDAOImpl__factory(deployer);
  const daoImpl = await daoImplFactory.deploy();
  return { token, timelock, daoImpl };
}

export async function raritySocietyDAOProxyFixture(
  signers: Signer[]
): Promise<RaritySocietyDAOProxyFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const admin: SignerWithAddress = signers[1] as SignerWithAddress;
  const vetoer: SignerWithAddress = signers[2] as SignerWithAddress;
  const tokenFactory = new MockERC721Token__factory(deployer);
  const token = await tokenFactory.deploy(deployer.address, 99);
  const daoImplFactory = new RaritySocietyDAOImpl__factory(deployer);
  const daoImpl = await daoImplFactory.deploy();
	const proxyAdminFactory = new RaritySocietyProxyAdmin__factory(deployer);
	const proxyAdmin = await proxyAdminFactory.deploy();
  const daoAddress = getContractAddress({
    from: deployer.address,
    nonce: (await deployer.getTransactionCount()) + 1,
  });
  const timelockFactory = new Timelock__factory(deployer);
  const timelock = await timelockFactory.deploy(
    daoAddress,
    Constants.TIMELOCK_DELAY
  );
  const daoFactory = new RaritySocietyDAOProxy__factory(deployer);
	const iface = new ethers.utils.Interface([
		"function initialize(address daoAdmin, address timelock_, address token_, address vetoer_, uint256 votingPeriod_, uint256 votingDelay_, uint256 proposalThreshold_, uint256 quorumVotesBPS_)",
	]);
	const initCallData = iface.encodeFunctionData("initialize", [
		admin.address,
		timelock.address,
		token.address,
		vetoer.address,
		Constants.VOTING_PERIOD,
		Constants.VOTING_DELAY,
    Constants.PROPOSAL_THRESHOLD,
    Constants.QUORUM_VOTES_BPS,
	]);
  const dao = await daoFactory.deploy(
    daoImpl.address,
    proxyAdmin.address,
		initCallData
  );
  const daoProxyImpl = daoImplFactory.attach(dao.address);
  return { token, timelock, dao, daoProxyImpl, daoImpl, proxyAdmin };
}
