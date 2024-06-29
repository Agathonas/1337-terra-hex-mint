
import { Account, Contract, json, RpcProvider, constants, cairo, CallData, Calldata } from "starknet";

export async function getAccount(provider: RpcProvider): Promise<Account> {
    const privateKey = process.env.PRIVATE_KEY ?? "";
    const accountAddress0: string = process.env.PUBLIC_KEY ?? "";
    const account0 = new Account(provider, accountAddress0, privateKey);
    console.log('account imported:::', account0.address)
    return (account0);
}
