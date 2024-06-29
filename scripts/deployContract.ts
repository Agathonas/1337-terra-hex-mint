
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

    await deployContract(provider, account, deployments)

}

async function deployContract(provider: RpcProvider, account: Account, deployments: any) {
    console.log('✅ Deploying ........');
    const contractConstructor: Calldata = CallData.compile({
        owner: account.address
    });

    const response = await account.deployContract({
        classHash: deployments.NFTMint.class_hash,
        constructorCalldata: contractConstructor
    });

    await provider.waitForTransaction(response.transaction_hash);
    console.log('✅  NFTMint deployed ........at:', response.contract_address);
    deployments.NFTMint = { class_hash: deployments.NFTMint.class_hash, address: response.contract_address };
    await writeFile(contracts, JSON.stringify(deployments, null, 2));
}


main()
    .then(() => process.exit(0))
    .catch((error) => { console.error(error); process.exit(1); });