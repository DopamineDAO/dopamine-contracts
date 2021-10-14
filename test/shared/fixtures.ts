import { Signer } from "@ethersproject/abstract-signer";
import {
  RaritySocietyToken,
  RaritySocietyToken__factory,
  IProxyRegistry,
  MockProxyRegistry__factory,
} from "../../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

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
