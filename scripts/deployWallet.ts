import { ethers } from "hardhat";
const { RANCE} = process.env;
import { MasterRANCEWallet } from "../src/types/MasterRANCEWallet";

async function main() {
  const Wallet = await ethers.getContractFactory("MasterRANCEWallet")
  const wallet: MasterRANCEWallet = 
    (await Wallet.deploy(RANCE)) as MasterRANCEWallet;

  console.log(`Wallet deployed to:${wallet.address}`);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
