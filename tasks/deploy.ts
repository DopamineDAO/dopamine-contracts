import fs from "fs";
import { task, types } from "hardhat/config";

// Listed in order of deployment. Wrong order results in error.
enum Contract {
  RaritySocietyToken,
  Timelock,
  RaritySocietyDAOImpl,
  RaritySocietyDAOProxy,
}

type Args = (string | number)[];
interface VerifyParams {
  args: Args;
  address: string;
	path?: string;
}

task("deploy-local", "Deploy Rarity Society contracts locally").setAction(
  async (args, { run }) => {
    await run("deploy", {
      chainid: 31337,
      registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
    });
  }
);

task("deploy-testing", "Deploy Rarity Society contracts to Ropsten")
  .addParam("verify", "whether to verify on Etherscan", false, types.boolean)
  .setAction(async (args, { run }) => {
    await run("deploy", {
      chainid: 3,
      registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
      verify: args.verify,
    });
  });

task("deploy-staging", "Deploy Rarity Society contracts to Rinkeby").setAction(
  async (args, { run }) => {
    await run("deploy", {
      chainid: 4,
      registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
    });
  }
);

task(
  "deploy-prod",
  "Deploy Rarity Society contracts to Ethereum Mainnet"
).setAction(async (args, { run }) => {
  await run("deploy", {
    chainid: 1,
    registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
  });
});

task("deploy", "Deploys Rarity Society contracts")
  .addParam("chainid", "expected network chain ID", undefined, types.int)
  .addParam(
    "registry",
    "OpenSea proxy registry address",
    undefined,
    types.string
  )
  .addOptionalParam(
    "verify",
    "whether to verify on Etherscan",
    true,
    types.boolean
  )
  .addOptionalParam(
    "minter",
    "Rarity Society token minter",
    undefined,
    types.string
  )
  .addOptionalParam(
    "vetoer",
    "Rarity Society DAO veto address",
    undefined,
    types.string
  )
  .addOptionalParam(
    "timelockDelay",
    "timelock delay (seconds)",
    60 * 60 * 24 * 2,
    types.int
  )
  .addOptionalParam(
    "votingPeriod",
    "proposal voting period (# of blocks)",
    32000,
    types.int
  )
  .addOptionalParam(
    "votingDelay",
    "proposal voting delay (# of blocks)",
    13000,
    types.int
  )
  .addOptionalParam(
    "proposalThreshold",
    "proposal threshold (# of NFTs)",
    1,
    types.int
  )
  .addOptionalParam(
    "quorumVotesBPS",
    "proposal quorum votes (basis points)",
    1000,
    types.int
  )
  .setAction(async (args, { ethers, run }) => {
    const gasPrice = await ethers.provider.getGasPrice();

    const network = await ethers.provider.getNetwork();
    if (network.chainId != args.chainid) {
      console.log(
        `invalid chain ID, expected: ${args.chainid} got: ${network.chainId}`
      );
      return;
    }

    console.log(
      `Deploying Rarity Society contracts to chain ${network.chainId}`
    );

    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${deployer.address}`);
    console.log(
      `Deployer balance: ${ethers.utils.formatEther(
        await deployer.getBalance()
      )} ETH`
    );
    const nonce = await deployer.getTransactionCount();
    let currNonce = nonce;

    const deployContract = async function (
      contract: string,
      args: (string | number)[],
      currNonce: number
    ): Promise<string> {
      console.log(`\nDeploying contract ${contract}:`);

      const expectedNonce = nonce + Contract[contract as keyof typeof Contract];
      if (currNonce != expectedNonce) {
        throw new Error(
          `Unexpected transaction nonce, got: ${currNonce} expected: ${expectedNonce}`
        );
      }
      const contractFactory = await ethers.getContractFactory(contract);

      const gas = await contractFactory.signer.estimateGas(
        contractFactory.getDeployTransaction(...args, { gasPrice })
      );
      const cost = ethers.utils.formatUnits(gas.mul(gasPrice), "ether");
      console.log(`Estimated deployment cost for ${contract}: ${cost}ETH`);

			const deployedContract = await contractFactory.deploy(...args);
			await deployedContract.deployed();

      console.log(`Contract ${contract} deployed to ${deployedContract.address}`);
      return deployedContract.address;
    };

    // 1. Deploy RaritySocietyToken:
    const raritySocietyTokenArgs: Args = [
      args.minter || deployer.address,
      args.registry,
    ];
    const raritySocietyToken = await deployContract(
      Contract[Contract.RaritySocietyToken],
      raritySocietyTokenArgs,
      currNonce++
    );

    // 2. Deploy Timelock
    const timelockArgs = [
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.RaritySocietyDAOProxy,
      }),
      args.timelockDelay,
    ];
    const timelock = await deployContract(
      Contract[Contract.Timelock],
      timelockArgs,
      currNonce++
    );

    // 3. Deploy Rarity Society DAO Impl
    const raritySocietyDAOImplArgs: Args = [];
    const raritySocietyDAOImpl = await deployContract(
      Contract[Contract.RaritySocietyDAOImpl],
      raritySocietyDAOImplArgs,
      currNonce++
    );

    // 4. Deploy Rarity Society DAO Proxy
    const raritySocietyDAOProxyArgs: Args = [
      timelock,
      raritySocietyToken,
      args.vetoer || deployer.address,
      timelock,
      raritySocietyDAOImpl,
      args.votingPeriod,
      args.votingDelay,
      args.proposalThreshold,
      args.quorumVotesBPS,
    ];
    const raritySocietyDAOProxy = await deployContract(
      Contract[Contract.RaritySocietyDAOProxy],
      raritySocietyDAOProxyArgs,
      currNonce++
    );

    if (args.verify) {
      const toVerify: Record<string, VerifyParams> = {
        raritySocietyToken: {
          address: raritySocietyToken,
          args: raritySocietyTokenArgs,
        },
        raritySocietyDAOImpl: {
          address: raritySocietyDAOImpl,
          args: raritySocietyDAOImplArgs,
					path: "contracts/governance/RaritySocietyDAOImpl.sol:RaritySocietyDAOImpl",
        },
        raritySocietyDAOProxy: {
          address: raritySocietyDAOProxy,
          args: raritySocietyDAOProxyArgs,
        },
      };
      for (const contract in toVerify) {
				console.log(`\nVerifying contract ${contract}:`)
				for (let i = 0; i < 3; i++) {
					try {
						if (toVerify[contract].path) {
							await run("verify:verify", {
								address: toVerify[contract].address,
								constructorArguments: toVerify[contract].args,
								contract: toVerify[contract].path,
							});
						} else {
							await run("verify:verify", {
								address: toVerify[contract].address,
								constructorArguments: toVerify[contract].args,
							});
						}
						console.log(`Contract ${contract} succesfully verified!`);
						break
					} catch(e: unknown) {
						let msg: string;
						if (e instanceof Error) {
							msg = e.message
						} else {
							msg = String(e);
						}
						if (msg.includes('Already Verified')) {
							console.log(`Contract ${contract} already verified!`)
							break
						}
						console.log(`Error verifying contract ${contract}: ${msg}`, msg);
						return;
					}
				}
      }
    }
    // if (!fs.existsSync('logs')) {
    // 	fs.mkdirSync('logs');
    // }
    // fs.writeFileSync(
    // 	'logs/deploy.json',
    // 	JSON.stringify({
    // 		addresses: {
    // 		},
    // 	}),
    // 	{ flag: 'w' },
    // );
  });
