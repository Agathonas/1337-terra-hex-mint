
import { Account, Contract, json, RpcProvider, constants, cairo, CallData, Calldata } from "starknet";
import fs from "fs";
import * as dotenv from "dotenv";
dotenv.config();
import { readFile, writeFile } from "fs/promises";
import { getAccount } from './utils';

const nodeUrl = "https://free-rpc.nethermind.io/sepolia-juno";
const contracts = `scripts/contracts.json`;


async function main() {
    const provider = new RpcProvider({ nodeUrl: nodeUrl });
    const account = await getAccount(provider)
    let deployments;
    const jsonFile = await readFile(contracts, "utf-8");
    deployments = JSON.parse(jsonFile);

    await declareContract(account, provider, deployments, 'NFTMint')

}


async function declareContract(account: Account, provider: RpcProvider, deployments: any, contractName: string) {
    console.log(' declaring ', contractName);

    const sierraFilePath = `./target/dev/terracon_prestige_card_${contractName}.contract_class.json`;
    const casmFilePath = `./target/dev/terracon_prestige_card_${contractName}.compiled_contract_class.json`;

    const compiledTestSierra = json.parse(fs.readFileSync(sierraFilePath).toString("ascii"));
    const compiledTestCasm = json.parse(fs.readFileSync(casmFilePath).toString("ascii"));

    const declareResponse = await account.declare({ contract: compiledTestSierra, casm: compiledTestCasm });

    console.log(contractName, ' declared with classHash =', declareResponse.class_hash);
    await provider.waitForTransaction(declareResponse.transaction_hash);
    deployments[contractName] = { class_hash: declareResponse.class_hash };
    await writeFile(contracts, JSON.stringify(deployments, null, 2));
}


main()
    .then(() => process.exit(0))
    .catch((error) => { console.error(error); process.exit(1); });