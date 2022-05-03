// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const account = new ethers.Wallet(process.env.PRIVATE_KEY);
const signer = account.connect(provider);

const gasTankAddress = "0xCfbCCC95E48D481128783Fa962a1828f47Fc8A42";
const payeeAddress = "";


// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------

async function depositGas(gt, receiver, amount) {
  return await gt.depositGas(receiver, {value: amount});
}

// ----------------------------------------------------------------------------------

async function withdrawGas(gt, amount) {
  return await gt.depositGas(amount);
}

// ----------------------------------------------------------------------------------

async function addPayee(gt, payee) {
  return await gt.addPayee(payee);
}

// ----------------------------------------------------------------------------------

async function removePayee(gt, payee) {
  return await gt.removePayee(payee);
}

// ----------------------------------------------------------------------------------

async function emergencyWithdraw(gt, token, amount) {
  return await gt.emergencyWithdraw(token, amount);
}

// ----------------------------------------------------------------------------------

async function pay(gt, payer, payee, amount) {
  return await gt.pay(payer, payee, amount);
}

// ----------------------------------------------------------------------------------

async function approve(gt, payee, approve) {
  return await gt.approve(payee, approve);
}

// ----------------------------------------------------------------------------------

async function main() {
  const GasTank = await ethers.getContractFactory("GasTank");
  const gasTank = await GasTank.attach(gasTankAddress);

  // **** Examples ****
  // await addPayee(gasTank, signer.address);
  // await removePayee(gasTank, signer.address);
  // await approve(gasTank, payeeAddress, true);
  // await pay(gasTank, signer.address, payeeAddress, hre.ethers.utils.parseUnits("0.0001", "ether"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
