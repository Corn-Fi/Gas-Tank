// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const hre = require("hardhat");
const TimeLock = require("../artifacts/contracts/interfaces/ITimelock.sol/ITimelock.json");
const GasTank = require("../artifacts/contracts/interfaces/IGasTank.sol/IGasTank.json");
const { addresses } = require("./addresses");
const TX_DELAY = ethers.BigNumber.from(86400);  // 1 Day


// ----------------------------------------------------------------------------------
// -------------------------------- Helper Functions --------------------------------
// ----------------------------------------------------------------------------------

async function fetchSigner() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
  const signer = wallet.connect(provider);
  console.log(`connected to ${signer.address}`);
  return signer;
}

// ----------------------------------------------------------------------------------

async function fetchContract(address, abi, signer) {
  const contract = new ethers.Contract(address, abi, signer);
  console.log(`loaded contract ${contract.address}`);
  return contract;
}

// ----------------------------------------------------------------------------------
// ------------------------------- Timelock Functions -------------------------------
// ----------------------------------------------------------------------------------

async function scheduleTransaction(target, value, data, predecessor, salt, delay) {
  const signer = await fetchSigner();
  const timelock = await fetchContract(addresses.timelock, TimeLock.abi, signer);
  return await timelock.schedule(target, value, data, predecessor, salt, delay);
}

// ----------------------------------------------------------------------------------

async function executeTransaction(target, value, data, predecessor, salt) {
  const signer = await fetchSigner();
  const timelock = await fetchContract(addresses.timelock, TimeLock.abi, signer);
  await timelock.execute(target, value, data, predecessor, salt);
}

// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------

async function depositGas(receiver, amount) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  return await gt.depositGas(receiver, {value: amount});
}

// ----------------------------------------------------------------------------------

async function withdrawGas(amount) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  return await gt.depositGas(amount);
}

// ----------------------------------------------------------------------------------

async function pay(payer, payee, amount) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  return await gt.pay(payer, payee, amount);
}

// ----------------------------------------------------------------------------------

async function approve(payee, approve) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  return await gt.approve(payee, approve);
}

// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------

async function addPayee(schedule, delay, payee) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  const rawTx = await gt.populateTransaction.addPayee(payee);

  if(schedule) {
    return await scheduleTransaction(gt.address, zero, rawTx.data, hashZero, hashZero, delay);
  }
  else {
    return await executeTransaction(gt.address, zero, rawTx.data, hashZero, hashZero);
  }
}

// ----------------------------------------------------------------------------------

async function removePayee(schedule, delay, payee) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  const rawTx = await gt.populateTransaction.removePayee(payee);

  if(schedule) {
    return await scheduleTransaction(gt.address, zero, rawTx.data, hashZero, hashZero, delay);
  }
  else {
    return await executeTransaction(gt.address, zero, rawTx.data, hashZero, hashZero);
  }
}

// ----------------------------------------------------------------------------------

async function emergencyWithdraw(schedule, delay, token, amount) {
  const signer = await fetchSigner();
  const gt = await fetchContract(addresses.gasTank, GasTank.abi, signer)
  const rawTx = await gt.populateTransaction.emergencyWithdraw(token, amount);

  if(schedule) {
    return await scheduleTransaction(gt.address, zero, rawTx.data, hashZero, hashZero, delay);
  }
  else {
    return await executeTransaction(gt.address, zero, rawTx.data, hashZero, hashZero);
  }
}

// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------

async function main() {
  // **** Examples ****
  // await addPayee(true, 30, signer.address);
  // await removePayee(gasTank, signer.address);
  // await approve(payeeAddress, true);
  // await pay(signer.address, payeeAddress, hre.ethers.utils.parseUnits("0.0001", "ether"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
