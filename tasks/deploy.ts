import fs from "fs";
import { default as DopamineAuctionHouseABI } from '../abi/src/auction/DopamineAuctionHouse.sol/DopamineAuctionHouse.json';
import { default as DopamineDAOABI } from '../abi/src/governance/DopamineDAO.sol/DopamineDAO.json';
import { Interface } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

// Listed in order of deployment. Wrong order results in error.
enum Contract {
  DopamintPass,
	DopamineAuctionHouse,
	DopamineAuctionHouseProxy,
  Timelock,
	DopamineDAO,
	DopamineDAOProxy,
}

type Args = (string | number)[];
interface VerifyParams {
  args: Args;
  address: string;
	path?: string;
}

task("deploy-local", "Deploy Dopamine contracts locally").setAction(
  async (args, { run }) => {
    await run("deploy", {
      chainid: 31337,
      registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
    });
  }
);

task("deploy-rinkeby", "Deploy Rarity Society contracts to Rinkeby")
  .addParam("verify", "whether to verify on Etherscan", true, types.boolean)
  .setAction(async (args, { run }) => {
    await run("deploy", {
      chainid: 4,
      registry: "0x1e525eeaf261ca41b809884cbde9dd9e1619573a",
      verify: args.verify,
    });
  });

task("deploy-goerli", "Deploy Rarity Society contracts to Goerli")
  .addParam("verify", "whether to verify on Etherscan", true, types.boolean)
	.setAction(
		async (args, { run }) => {
			await run("deploy", {
				chainid: 5,
				registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
				verify: args.verify,
		});
	});

task(
  "deploy-prod",
  "Deploy Dopamine contracts to Ethereum Mainnet"
).setAction(async (args, { run }) => {
  await run("deploy", {
    chainid: 1,
    registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
  });
});

task("deploy", "Deploys Dopamine contracts")
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
    "whitelistSize",
    "number of slots to reserve for whitelist minting",
    10,
    types.int
  )
  .addOptionalParam(
    "maxSupply",
    "total number of NFTs to reserve for minting",
    9999,
    types.int
  )
	.addOptionalParam(
		"treasurySplit",
		"% of auction revenue directed to Dopamine DAO",
		50,
		types.int
	)
	.addOptionalParam(
		"dropSize",
		"# of DopamintPasses to distribute for a given drop",
		99,
		types.int
	)
	.addOptionalParam(
		"dropDelay",
		"time in seconds to wait between drops",
		60 * 60 * 24 * 33,
		types.int
	)
	.addOptionalParam(
		"timeBuffer",
		"time in seconds to add for auction extensions",
		60 * 10,
		types.int
	)
	.addOptionalParam(
		"reservePrice",
		"starting reserve price for auctions",
		1,
		types.int
	)
	.addOptionalParam(
		"duration",
		"how long each auction should last",
		60 * 10,
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

    // 1. Deploy DopamintPass:
    const dopamintPassArgs: Args = [
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.DopamineAuctionHouseProxy,
      }),
      args.registry,
			args.dropSize,
			args.dropDelay,
			args.whitelistSize,
			args.maxSupply
    ];
    const dopamintPass = await deployContract(
      Contract[Contract.DopamintPass],
      dopamintPassArgs,
      currNonce++
    );

    // 2. Deploy auction house.
    const dopamineAuctionHouse = await deployContract(
      Contract[Contract.DopamineAuctionHouse],
      [],
      currNonce++
    );

		// 3. Deploy auction house proxy.
    const dopamineAuctionHouseProxyArgs = [
			dopamineAuctionHouse,
      new Interface(DopamineAuctionHouseABI).encodeFunctionData('initialize', [
				dopamintPass,
				deployer.address,
				ethers.utils.getContractAddress({
					from: deployer.address,
					nonce: nonce + Contract.DopamineDAOProxy,
				}),
				args.treasurySplit,
				args.timeBuffer,
				args.reservePrice,
				args.duration
			]),
    ];
    const dopamineAuctionHouseProxy = await deployContract(
      Contract[Contract.DopamineAuctionHouseProxy],
      dopamineAuctionHouseProxyArgs,
      currNonce++
    );

		// 4. Deploy timelock.
    const timelockArgs = [
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.DopamineDAOProxy,
      }),
      args.timelockDelay,
    ];
    const timelock = await deployContract(
      Contract[Contract.Timelock],
      timelockArgs,
      currNonce++
    );

    // 5. Deploy Dopamine DAO
    const dopamineDAOArgs: Args = [
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.DopamineDAOProxy,
      }),
		];
    const dopamineDAO = await deployContract(
      Contract[Contract.DopamineDAO],
      dopamineDAOArgs,
      currNonce++
    );

    // 6. Deploy Dopamine DAO Proxy
    const dopamineDAOProxyArgs = [
			dopamineDAO,
      new Interface(DopamineDAOABI).encodeFunctionData('initialize', [
				timelock,
				dopamintPass,
				args.vetoer || deployer.address,
				args.votingPeriod,
				args.votingDelay,
				args.proposalThreshold,
				args.quorumVotesBPS
			]),
    ];
    const dopamineDAOProxy = await deployContract(
      Contract[Contract.DopamineDAOProxy],
      dopamineDAOProxyArgs,
      currNonce++
    );

    if (args.verify) {
      const toVerify: Record<string, VerifyParams> = {
        dopamintPass: {
          address: dopamintPass,
          args: dopamintPassArgs,
        },
				dopamineAuctionHouse: {
					address: dopamineAuctionHouse,
					args: [],
				},
				dopamineAuctionHouseProxy: {
					address: dopamineAuctionHouseProxy,
					args: dopamineAuctionHouseProxyArgs,
					path: "src/auction/DopamineAuctionHouseProxy.sol:DopamineAuctionHouseProxy",
				},
				timelock: {
					address: timelock,
					args: timelockArgs,
				},
        dopamineDAO: {
          address: dopamineDAO,
          args: dopamineDAOArgs,
        },
				dopamineDAOProxy: {
					address: dopamineDAOProxy,
					args: dopamineDAOProxyArgs,
					path: "src/governance/DopamineDAOProxy.sol:DopamineDAOProxy",
				}
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
