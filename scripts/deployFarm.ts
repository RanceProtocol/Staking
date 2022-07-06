import { ethers, upgrades } from "hardhat";
const { WALLET, RANCE } = process.env;
import { MasterRANCEWallet } from "../src/types/MasterRANCEWallet";

async function main() {
  // We get the contract to deploy
  const RANCEPerBlock = 10000000000;

  const wallet: MasterRANCEWallet = (await ethers.getContractAt("MasterRANCEWallet", WALLET!)) as MasterRANCEWallet;
  const Farm = await ethers.getContractFactory("MasterRANCE");
  const farm = await upgrades.deployProxy(Farm, [RANCE, RANCEPerBlock, 0, wallet.address], {kind: "uups"})
  await wallet.setMasterRANCE(farm.address);

  console.log(`Farm deployed to:${farm.address}, wallet deployed to:${wallet.address}`,
  `implementation deployed to:${await ethers.provider.getStorageAt(
    farm.address,
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    )}`);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
