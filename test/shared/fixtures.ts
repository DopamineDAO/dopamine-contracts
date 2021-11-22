import { Signer } from "@ethersproject/abstract-signer";
import { getContractAddress } from "@ethersproject/address";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Constants } from "./constants";
import {
  RaritySocietyToken,
  RaritySocietyToken__factory,
  MockERC721Token__factory,
  MockERC721Token,
  MockRaritySocietyDAOImpl__factory,
  MockRaritySocietyDAOImpl,
  RaritySocietyDAOImpl__factory,
  RaritySocietyDAOImpl,
  RaritySocietyDAOProxy__factory,
  RaritySocietyDAOProxy,
  Timelock,
  Timelock__factory,
  IProxyRegistry,
  MockProxyRegistry__factory,
} from "../../typechain";

export type RaritySocietyDAOProxyFixture = {
  token: RaritySocietyToken;
  timelock: Timelock;
  dao: RaritySocietyDAOProxy;
  daoProxyImpl: RaritySocietyDAOImpl;
  daoImpl: RaritySocietyDAOImpl;
};

export type RaritySocietyDAOImplFixture = {
  token: RaritySocietyToken;
  timelock: Timelock;
  daoImpl: MockRaritySocietyDAOImpl;
  daoImplFactory: MockRaritySocietyDAOImpl__factory;
};

export type RaritySocietyTokenFixture = {
  token: RaritySocietyToken;
  registry: IProxyRegistry;
};

export async function raritySocietyTokenFixture(
  signers: Signer[]
): Promise<RaritySocietyTokenFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const tokenFactory = new RaritySocietyToken__factory(deployer);
  const registryFactory = new MockProxyRegistry__factory(deployer);
  const registry = await registryFactory.deploy();
  const token = await tokenFactory.deploy(deployer.address, registry.address);
  return { token, registry };
}

export async function erc721TokenFixture(
  signers: Signer[]
): Promise<MockERC721Token> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const tokenFactory = new MockERC721Token__factory(deployer);
  const token = await tokenFactory.deploy(deployer.address);
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

export async function raritySocietyDAOImplFixture(
  signers: Signer[]
): Promise<RaritySocietyDAOImplFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const admin: SignerWithAddress = signers[1] as SignerWithAddress;
  const vetoer: SignerWithAddress = signers[2] as SignerWithAddress;
  const tokenFactory = new RaritySocietyToken__factory(deployer);
  const registryFactory = new MockProxyRegistry__factory(deployer);
  const registry = await registryFactory.deploy();
  const token = await tokenFactory.deploy(deployer.address, registry.address);
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
  const daoImplFactory = new MockRaritySocietyDAOImpl__factory(deployer);
  const daoImpl = await daoImplFactory.deploy(
    timelock.address,
    token.address,
    vetoer.address,
    admin.address,
    Constants.VOTING_PERIOD,
    Constants.VOTING_DELAY,
    Constants.PROPOSAL_THRESHOLD,
    Constants.QUORUM_VOTES_BPS
  );
  return { token, timelock, daoImplFactory, daoImpl };
}

export async function raritySocietyDAOProxyFixture(
  signers: Signer[]
): Promise<RaritySocietyDAOProxyFixture> {
  const deployer: SignerWithAddress = signers[0] as SignerWithAddress;
  const admin: SignerWithAddress = signers[1] as SignerWithAddress;
  const vetoer: SignerWithAddress = signers[2] as SignerWithAddress;
  const tokenFactory = new RaritySocietyToken__factory(deployer);
  const registryFactory = new MockProxyRegistry__factory(deployer);
  const registry = await registryFactory.deploy();
  const token = await tokenFactory.deploy(deployer.address, registry.address);
  const daoImplFactory = new RaritySocietyDAOImpl__factory(deployer);
  const daoImpl = await daoImplFactory.deploy();
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
  const dao = await daoFactory.deploy(
    timelock.address,
    token.address,
    vetoer.address,
    admin.address,
    daoImpl.address,
    Constants.VOTING_PERIOD,
    Constants.VOTING_DELAY,
    Constants.PROPOSAL_THRESHOLD,
    Constants.QUORUM_VOTES_BPS
  );
  const daoProxyImpl = daoImplFactory.attach(dao.address);
  return { token, timelock, dao, daoProxyImpl, daoImpl };
}
