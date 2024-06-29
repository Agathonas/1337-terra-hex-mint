use core::hash::HashStateExTrait;
use core::{ArrayTrait, SpanTrait};
use core::debug::PrintTrait;
use terracon_prestige_card::nft_mint::interface::{
    INFTMint, INFTMintDispatcher, INFTMintDispatcherTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

use starknet::{ContractAddress, deploy_syscall};
use starknet::contract_address_const;
use starknet::contract_address_try_from_felt252;
use starknet::contract_address_to_felt252;
use openzeppelin::token::erc721::interface::{
    ERC721ABI, ERC721ABIDispatcher, ERC721ABIDispatcherTrait
};
use snforge_std::{ContractClassTrait, declare, cheat_caller_address, CheatSpan};
use terracon_prestige_card::types::{TokenMetadata, Attribute, Stat};

const MAX_TOKENS_PER_ADDRESS: u256 = 2;
const MINTING_FEE: u256 = 33000000000000000; // 0.033 ether
const MAX_SUPPLY: u256 = 1337;
const OWNER_FREE_MINT_AMOUNT: u256 = 337;
const WHITELIST_FREE_MINT_END: u256 = 437; // 437

const TOKEN_SUPPLY_F: felt252 = 100000000000000000000000000;
const TOKEN_SUPPLY: u256 = 100000000000000000000000000;

const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

const MERKLE_ROOT: felt252 = 0x06e1ca6734406be8b8390672e63de35b020172fb415d4f5e6ed604c628c3802b;

#[test]
fn test_init() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    let NFTMintErc721 = ERC721ABIDispatcher { contract_address: NFTMint.contract_address };

    assert(NFTMintErc721.name() == format!("Terracon Hex Prestige Card"), 'Error:: name');
    assert(NFTMintErc721.symbol() == format!("HEX"), 'Error:: symbol');

    assert(NFTMintErc721.balance_of(_OWNER) == OWNER_FREE_MINT_AMOUNT, 'Error:: owner balance');
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 1, 'Error:: total sup');

    assert(NFTMintErc721.owner_of(1) == _OWNER, 'Error:: token1 owner');
    assert(NFTMintErc721.owner_of(OWNER_FREE_MINT_AMOUNT) == _OWNER, 'Error:: token  owner');

    assert(NFTMint.mint_fee(ETH_ADDRESS.try_into().unwrap()) == MINTING_FEE, 'Error:: mint_fee');

    assert(
        NFTMint.token_of_owner_by_index_len(_OWNER) == OWNER_FREE_MINT_AMOUNT,
        'Error:: owner tokens len'
    );

    assert(NFTMint.token_of_owner_by_index(_OWNER, 0) == 1, 'Error:: tokens index');
    assert(
        NFTMint
            .token_of_owner_by_index(_OWNER, OWNER_FREE_MINT_AMOUNT - 1) == OWNER_FREE_MINT_AMOUNT,
        'Error:: tokens index'
    );

    assert(NFTMint.get_whitelisted_max_amount() == 200, 'Error:: max index');
}

#[test]
fn test_erc721() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    let NFTMintErc721 = ERC721ABIDispatcher { contract_address: NFTMint.contract_address };

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(4));
    NFTMintErc721.transfer_from(_OWNER, _ACCOUNT1, 1);
    NFTMintErc721.transfer_from(_OWNER, _ACCOUNT1, 2);
    NFTMintErc721.transfer_from(_OWNER, _ACCOUNT1, 3);
    NFTMintErc721.transfer_from(_OWNER, _ACCOUNT2, 4);

    assert(NFTMintErc721.balance_of(_OWNER) == OWNER_FREE_MINT_AMOUNT - 4, 'Error:: owner balance');
    assert(NFTMintErc721.balance_of(_ACCOUNT1) == 3, 'Error:: ac1 balance');
    assert(NFTMintErc721.balance_of(_ACCOUNT2) == 1, 'Error:: ac2 balance');

    assert(NFTMintErc721.owner_of(1) == _ACCOUNT1, 'Error:: token1 owner');
    assert(NFTMintErc721.ownerOf(1) == _ACCOUNT1, 'Error:: token1  owner');
    assert(NFTMintErc721.ownerOf(4) == _ACCOUNT2, 'Error:: token4  owner');

    assert(
        NFTMint.token_of_owner_by_index_len(_OWNER) == OWNER_FREE_MINT_AMOUNT - 4,
        'Error:: owner tokens len'
    );

    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT1) == 3, 'Error:: ac1 tokens len');
    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT2) == 1, 'Error:: ac2 tokens len');

    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 0) == 1, 'Error:: tokens index1');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 1) == 2, 'Error:: tokens index2');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 2) == 3, 'Error:: tokens index3');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT2, 0) == 4, 'Error:: tokens index4');

    assert(
        NFTMint.token_of_owner_by_index(_OWNER, 0) == OWNER_FREE_MINT_AMOUNT,
        'Error:: tokens index5'
    );
    assert(
        NFTMint.token_of_owner_by_index(_OWNER, 1) == OWNER_FREE_MINT_AMOUNT - 1,
        'Error:: tokens index6'
    );
    assert(
        NFTMint.token_of_owner_by_index(_OWNER, 2) == OWNER_FREE_MINT_AMOUNT - 2,
        'Error:: tokens index7'
    );
    assert(
        NFTMint.token_of_owner_by_index(_OWNER, 3) == OWNER_FREE_MINT_AMOUNT - 3,
        'Error:: tokens index8'
    );
    assert(NFTMint.token_of_owner_by_index(_OWNER, 4) == 5, 'Error:: tokens index9');

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMintErc721.transfer_from(_ACCOUNT1, _ACCOUNT3, 3);
    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT1) == 2, 'Error:: ac1 tokens len');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 0) == 1, 'Error:: tokens index9');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 1) == 2, 'Error:: tokens index10');
    assert(NFTMint.token_of_owner_by_index(_ACCOUNT1, 2) == 0, 'Error:: tokens index11');
}

#[test]
fn test_whitelist_functions() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);

    assert(NFTMint.is_whitelisted(_ACCOUNT1) == true, 'Error:: is_whitelisted');
    assert(NFTMint.is_whitelisted(_ACCOUNT2) == true, 'Error:: is_whitelisted2');
    assert(NFTMint.is_whitelisted(_ACCOUNT3) == true, 'Error:: is_whitelisted3');

    assert(
        NFTMint.all_whitelist_addresses() == array![_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3],
        'Error:: all_whitelist_addresses'
    );

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.remove_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT3]);

    assert(NFTMint.is_whitelisted(_ACCOUNT1) == false, 'Error:: is_whitelisted');
    assert(NFTMint.is_whitelisted(_ACCOUNT2) == true, 'Error:: is_whitelisted2');
    assert(NFTMint.is_whitelisted(_ACCOUNT3) == false, 'Error:: is_whitelisted3');

    assert(
        NFTMint.all_whitelist_addresses() == array![_OWNER, _ACCOUNT2],
        'Error:: whitelist_addresses2'
    );

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT3]);

    assert(NFTMint.is_whitelisted(_ACCOUNT1) == true, 'Error:: is_whitelisted');
    assert(NFTMint.is_whitelisted(_ACCOUNT2) == true, 'Error:: is_whitelisted2');
    assert(NFTMint.is_whitelisted(_ACCOUNT3) == true, 'Error:: is_whitelisted3');
    assert(
        NFTMint.all_whitelist_addresses() == array![_OWNER, _ACCOUNT2, _ACCOUNT1, _ACCOUNT3],
        'Error:: whitelist_addresses3'
    );
}

#[test]
fn test_authorize_functions() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_authorized_address(_ACCOUNT1);

    assert(NFTMint.is_authorized(_ACCOUNT1) == true, 'Error:: is_authorized');
    assert(NFTMint.is_authorized(_ACCOUNT2) == false, 'Error:: is_authorized');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.remove_authorized_address(_ACCOUNT1);
    assert(NFTMint.is_authorized(_ACCOUNT1) == false, 'Error:: is_authorized');
}

#[test]
fn test_whitelist_mint() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);
    let NFTMintErc721 = ERC721ABIDispatcher { contract_address: NFTMint.contract_address };

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(3));
    ETHContract.transfer(_ACCOUNT1, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT2, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT3, 1000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
    NFTMint.set_free_mint(true);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(3));
    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);

    assert(NFTMintErc721.owner_of(OWNER_FREE_MINT_AMOUNT + 1) == _ACCOUNT1, 'Error:: token owner');
    assert(NFTMint.is_whitelisted(_ACCOUNT1) == false, 'Error:: is_whitelisted');

    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT1) == 1, 'Error:: ac1 tokens len');

    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT1, 0) == OWNER_FREE_MINT_AMOUNT + 1,
        'Error:: tokens index1'
    );

    NFTMint.mint(_ACCOUNT2, 1, ETHContract.contract_address);
    NFTMint.mint(_ACCOUNT3, 1, ETHContract.contract_address);
    assert(NFTMint.is_whitelisted(_ACCOUNT2) == false, 'Error:: is_whitelisted');
    assert(NFTMint.is_whitelisted(_ACCOUNT3) == false, 'Error:: is_whitelisted');
    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT2, 0) == OWNER_FREE_MINT_AMOUNT + 2,
        'Error:: tokens index2'
    );
    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT3, 0) == OWNER_FREE_MINT_AMOUNT + 3,
        'Error:: tokens index3'
    );
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 4, 'Error:: total sup');

    assert(NFTMint.get_whitelisted_token_minted() == 3, 'Error:: wl minted');

    assert(NFTMint.get_whitelisted_max_amount() == 200, 'Error:: max index');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_whitelist_limit(100);
    assert(NFTMint.get_whitelisted_max_amount() == 100, 'Error:: max index');
}

#[test]
fn test_wl_limit() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(3));
    ETHContract.transfer(_ACCOUNT1, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT2, 1000 * MINTING_FEE);

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 10000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT1, 10, ETHContract.contract_address);

    assert(ETHContract.balance_of(_ACCOUNT1) == 990 * MINTING_FEE, 'Error:: balanceOf ac1');

    let mut i = 1_u32;

    while i < 201 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);

        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    assert(NFTMint.get_whitelisted_token_minted() == 200, 'Error:: wl minted');
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 211, 'Error:: total sup');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT2]);

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT2, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 10000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT2, CheatSpan::TargetCalls(2));
    NFTMint.mint(_ACCOUNT2, 1, ETHContract.contract_address);

    assert(NFTMint.get_whitelisted_token_minted() == 200, 'Error:: wl minted');
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 212, 'Error:: total sup2');
    assert(ETHContract.balance_of(_ACCOUNT2) == 999 * MINTING_FEE, 'Error:: balanceOf ac2');
}


#[test]
fn test_sale() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ACCOUNT4: ContractAddress = contract_address_const::<'account4'>();
    let (ETHContract, STRKContract, LORDSContract) = deploy_tokens(
        _OWNER, ETH_ADDRESS.try_into().unwrap()
    );

    let NFTMint = deploy(_OWNER);
    let NFTMintErc721 = ERC721ABIDispatcher { contract_address: NFTMint.contract_address };

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(3));
    ETHContract.transfer(_ACCOUNT1, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT2, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT3, 1000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    let mut i = 1_u32;
    while i < 101 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 1000 * MINTING_FEE);

    let owner_balance = ETHContract.balance_of(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT1, 2, ETHContract.contract_address);

    assert(ETHContract.balance_of(_ACCOUNT1) == 998 * MINTING_FEE, 'Error:: balanceOf ac1');
    assert(
        ETHContract.balance_of(_OWNER) == owner_balance + 2 * MINTING_FEE, 'Error:: balanceOf owner'
    );

    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 1) == _ACCOUNT1, 'Error:: token owner');
    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 2) == _ACCOUNT1, 'Error:: token owner');

    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT1) == 2, 'Error:: ac1 tokens len');

    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT1, 0) == WHITELIST_FREE_MINT_END + 1,
        'Error:: tokens index1'
    );
    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT1, 1) == WHITELIST_FREE_MINT_END + 2,
        'Error:: tokens index2'
    );

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT2, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 1000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT2, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT2, 1, ETHContract.contract_address);

    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT2) == 1, 'Error:: ac1 tokens len');

    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT2, 0) == WHITELIST_FREE_MINT_END + 3,
        'Error:: tokens index1'
    );

    assert(ETHContract.balance_of(_ACCOUNT2) == 999 * MINTING_FEE, 'Error:: balanceOf ac1');
    assert(
        ETHContract.balance_of(_OWNER) == owner_balance + 3 * MINTING_FEE,
        'Error:: balanceOf owner1'
    );

    let strk_fee = 10000000000000000000;
    let lords_fee = 50000000000000000000;

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_payment_tokens(STRKContract.contract_address, strk_fee);
    NFTMint.set_payment_tokens(LORDSContract.contract_address, lords_fee);

    assert(NFTMint.mint_fee(STRKContract.contract_address) == strk_fee, 'Error:: mint_fee');
    assert(NFTMint.mint_fee(LORDSContract.contract_address) == lords_fee, 'Error:: mint_fee2');

    cheat_caller_address(STRKContract.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    STRKContract.transfer(_ACCOUNT3, 100 * strk_fee);

    cheat_caller_address(LORDSContract.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    LORDSContract.transfer(_ACCOUNT4, 100 * lords_fee);

    cheat_caller_address(STRKContract.contract_address, _ACCOUNT3, CheatSpan::TargetCalls(1));
    STRKContract.approve(NFTMint.contract_address, 100000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT3, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT3, 2, STRKContract.contract_address);
    'mint'.print();

    assert(
        STRKContract.balance_of(_OWNER) == TOKEN_SUPPLY - 98 * strk_fee, 'Error:: balanceOf owner2'
    );

    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 4) == _ACCOUNT3, 'Error:: token owner');
    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 5) == _ACCOUNT3, 'Error:: token owner');

    assert(NFTMint.token_of_owner_by_index_len(_ACCOUNT3) == 2, 'Error:: ac3 tokens len');

    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT3, 0) == WHITELIST_FREE_MINT_END + 4,
        'Error:: tokens index1'
    );
    assert(
        NFTMint.token_of_owner_by_index(_ACCOUNT3, 1) == WHITELIST_FREE_MINT_END + 5,
        'Error:: tokens index2'
    );

    cheat_caller_address(LORDSContract.contract_address, _ACCOUNT4, CheatSpan::TargetCalls(1));
    LORDSContract.approve(NFTMint.contract_address, 100000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT4, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT4, 2, LORDSContract.contract_address);

    assert(
        LORDSContract.balance_of(_OWNER) == TOKEN_SUPPLY - 98 * lords_fee,
        'Error:: balanceOf owner3'
    );

    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 6) == _ACCOUNT4, 'Error:: token owner');
    assert(NFTMintErc721.owner_of(WHITELIST_FREE_MINT_END + 7) == _ACCOUNT4, 'Error:: token owner');
    assert(NFTMintErc721.owner_of(444) == _ACCOUNT4, 'Error:: token owner444');

    //444
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_merkle_root(MERKLE_ROOT);

    let token_id444: u256 = 444;
    let name1 = 'Pythagorasus';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'Peloponnese' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Spartans' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    let proof1 = array![
        0xd52c4b5bd686651a20a8eeb5a42e6067928d4d8b3ec1337f73848f5c814d1f,
        0x44e553fc99c78d4e035eaa3c5022a1fdaa2ae8d5b8b79ff6f3fa8fe851330e5,
        0x85a44dd349ca16ad60462a502593a4240f93ebefb019ad782354f05f736aa3,
        0x67fc8e9a49662ddb1cad1748c895e9f3091f29391c1eefefef923bebc35cd3b,
        0x5b769c40d6f1c3c97f6e5fe53bc6b320e8e28530a9ac8efe872f6c53a9d4b58,
        0x8dd9d582db056df84fefd7a637455e8a915930f36e98a1f63f6e9abd696058,
        0x113dea37be1e25b88e3733ae227f53f6ec11c670efa3f801e07c040d28d52e9,
        0x759cdc2e4ebc5f25150eb4efcd08ec4e3ee82ca84b9c7221a091f1cc636b746,
        0x56a6ac661ad66aa90ef6aa53c91ea52fe75d696fb8ad7094a926d4696baf930,
        0x1f38f47ab224ef905f3cbf88b39109b7aa8c0d78b2d773a45cf6acd82f6f003,
        0x78a063a051eea17b6e114091ff6a1c97813412155073b1a55e3419f52402952
    ];

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT4, CheatSpan::TargetCalls(1));
    NFTMint.reveal_token(token_id444, name1, attributes1.span(), proof1.span());

    assert(NFTMint.is_revealed(token_id444), 'Error:: is revealed');
    let metadata1 = NFTMint.get_token_metadata(token_id444);

    assert(metadata1.name == format!("Pythagorasus"), 'Error:: name');

    assert(
        metadata1
            .description == format!(
                "Pythagorasus is a character from Terracon Quest Autonomous World."
            ),
        'Error:: description'
    );

    assert(
        metadata1
            .image == format!(
                "https://terraconquest.mypinata.cloud/ipfs/QmUysuKZyMwoqPgdEatwc51HQCMqvjf2z7CmoHAqgtbWMD/444.png"
            ),
        'Error:: image'
    );
    assert(
        metadata1.external_url == format!("https://terracon.quest/Pythagorasus"),
        'Error:: external_url'
    );

    assert(NFTMint.get_token_attribute_len(token_id444) == 4, 'Error:: attribute_len');
    assert(
        NFTMint
            .get_token_attribute(
                token_id444, 0
            ) == Attribute { trait_type: 'birthplace', value: 'Peloponnese' },
        'Error:: attribute0'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id444, 1
            ) == Attribute { trait_type: 'ethnicity', value: 'Spartans' },
        'Error:: attribute1'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id444, 2
            ) == Attribute { trait_type: 'occupation', value: 'General' },
        'Error:: attribute2'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id444, 3
            ) == Attribute { trait_type: 'special_trait', value: 'None' },
        'Error:: attribute3'
    );
}

#[test]
fn test_wl_mint_when_public_finished() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 10000 * MINTING_FEE);

    let mut i = 1_u32;
    while i < 21 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);

        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    assert(NFTMint.get_whitelisted_token_minted() == 20, 'Error:: wl minted');
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 21, 'Error:: total sup');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_whitelist_limit(900);

    let mut j = 1_u32;
    while j < 6 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .mint(
                contract_address_try_from_felt252((j * 222).into()).unwrap(),
                20,
                ETHContract.contract_address
            );
        j += 1;
    };

    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 121, 'Error:: total sup2');
    assert(NFTMint.get_whitelisted_token_minted() == 20, 'Error:: wl minted');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT2,_ACCOUNT3]);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT2, 1, ETHContract.contract_address);

    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 122, 'Error:: total sup3');
    assert(NFTMint.get_whitelisted_token_minted() == 21, 'Error:: wl minted3');
    

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.mint(_ACCOUNT3, 1, ETHContract.contract_address);

    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 123, 'Error:: total sup3');
    assert(NFTMint.get_whitelisted_token_minted() == 22, 'Error:: wl minted3');
}


#[test]
fn test_reveal() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_merkle_root(MERKLE_ROOT);

    assert(NFTMint.get_merkle_root() == MERKLE_ROOT, 'Error:: saved root');

    let token_id1: u256 = 1;
    let name1 = 'Theseusides';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'West Macedonia' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Macedonians' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
        0x8c716ef984c8f0d28eaeb3953cbe744fd801666fc72b6ba76ab73783ffe7e7,
        0x1ea5f6c1e9b55ab8c90c0ec054bd26e73cd2315c321cf8ebc6dcfe6825996a3,
        0x3269866fed3f1037dd0842c0377789813059a5f161408cf69540a545b5b98f7,
        0x670931d08fd6143ff56c710e7133b3772beac178ce5e94f4c2fc46752212690,
        0x418ef66924acf7ee380515d2d9403cc6305eb8591b2f13eb089b78535e86719,
        0x7e006e3e813a9c414b5319e8000bb9ff236cc0f3d9df5bf93e3bd3bcf5590c8,
        0x56cfa47a8c941147f8d668abc703883d9bce3d629b5a25641578f06ba633948
    ];
    assert(
        NFTMint
            .get_root_for(name1, token_id1.low, attributes1.span(), proof1.span()) == MERKLE_ROOT,
        'Error:: token1 data'
    );

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.reveal_token(token_id1, name1, attributes1.span(), proof1.span());

    assert(NFTMint.is_revealed(token_id1), 'Error:: is revealed');

    let metadata1 = NFTMint.get_token_metadata(token_id1);

    assert(metadata1.name == format!("Theseusides"), 'Error:: name');

    assert(
        metadata1
            .description == format!(
                "Theseusides is a character from Terracon Quest Autonomous World."
            ),
        'Error:: description'
    );

    assert(
        metadata1
            .image == format!(
                "https://terraconquest.mypinata.cloud/ipfs/QmUysuKZyMwoqPgdEatwc51HQCMqvjf2z7CmoHAqgtbWMD/1.png"
            ),
        'Error:: image'
    );
    assert(
        metadata1.external_url == format!("https://terracon.quest/Theseusides"),
        'Error:: external_url'
    );

    assert(NFTMint.get_token_attribute_len(token_id1) == 4, 'Error:: attribute_len');
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 0
            ) == Attribute { trait_type: 'birthplace', value: 'West Macedonia' },
        'Error:: attribute0'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 1
            ) == Attribute { trait_type: 'ethnicity', value: 'Macedonians' },
        'Error:: attribute1'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 2
            ) == Attribute { trait_type: 'occupation', value: 'General' },
        'Error:: attribute2'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 3
            ) == Attribute { trait_type: 'special_trait', value: 'None' },
        'Error:: attribute3'
    );

    let mut attributes2 = ArrayTrait::<Attribute>::new();
    attributes2.append(Attribute { trait_type: 'birthplace1', value: 'Peloponnese1' });
    attributes2.append(Attribute { trait_type: 'ethnicity2', value: 'Spartans2' });
    attributes2.append(Attribute { trait_type: 'occupation3', value: 'General3' });
    attributes2.append(Attribute { trait_type: 'special_trait4', value: 'Courage' });
    attributes2.append(Attribute { trait_type: 'test', value: 'test' });

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_authorized_address(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.update_token_attributes(token_id1, attributes2.span());

    assert(NFTMint.get_token_attribute_len(token_id1) == 5, 'Error:: attribute_len2');
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 0
            ) == Attribute { trait_type: 'birthplace1', value: 'Peloponnese1' },
        'Error:: attribute4'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 1
            ) == Attribute { trait_type: 'ethnicity2', value: 'Spartans2' },
        'Error:: attribute5'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 2
            ) == Attribute { trait_type: 'occupation3', value: 'General3' },
        'Error:: attribute6'
    );
    assert(
        NFTMint
            .get_token_attribute(
                token_id1, 3
            ) == Attribute { trait_type: 'special_trait4', value: 'Courage' },
        'Error:: attribute7'
    );
    assert(
        NFTMint
            .get_token_attribute(token_id1, 4) == Attribute { trait_type: 'test', value: 'test' },
        'Error:: attribute8'
    );

    let mut stats = ArrayTrait::<Stat>::new();
    stats.append(Stat { stat_type: 'birthplace1', value: 111 });
    stats.append(Stat { stat_type: 'ethnicity2', value: 222 });
    stats.append(Stat { stat_type: 'occupation3', value: 333 });

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.update_token_stats(token_id1, stats.span());

    assert(NFTMint.get_token_stat_len(token_id1) == 3, 'Error:: attribute_len2');
    assert(
        NFTMint.get_token_stat(token_id1, 0) == Stat { stat_type: 'birthplace1', value: 111 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 1) == Stat { stat_type: 'ethnicity2', value: 222 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 2) == Stat { stat_type: 'occupation3', value: 333 },
        'Error:: stat'
    );

    stats.append(Stat { stat_type: 'str', value: 4444 });

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.update_token_stats(token_id1, stats.span());

    assert(NFTMint.get_token_stat_len(token_id1) == 4, 'Error:: attribute_len2');
    assert(
        NFTMint.get_token_stat(token_id1, 0) == Stat { stat_type: 'birthplace1', value: 111 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 1) == Stat { stat_type: 'ethnicity2', value: 222 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 2) == Stat { stat_type: 'occupation3', value: 333 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 3) == Stat { stat_type: 'str', value: 4444 },
        'Error:: stat'
    );
}

#[test]
fn test_stat_reveal() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());
    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_authorized_address(_OWNER);

    let token_id1: u256 = 1;
    let mut stats = ArrayTrait::<Stat>::new();
    stats.append(Stat { stat_type: 'birthplace1', value: 111 });
    stats.append(Stat { stat_type: 'ethnicity2', value: 222 });
    stats.append(Stat { stat_type: 'occupation3', value: 333 });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
    ];

    let root = NFTMint.get_stat_root_for(token_id1.low, stats.span(), proof1.span());

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_stat_merkle_root(root);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.reveal_stats(token_id1, stats.span(), proof1.span());

    assert(NFTMint.is_stats_revealed(token_id1), 'Error:: is revealed');

    assert(NFTMint.get_token_stat_len(token_id1) == 3, 'Error:: stat len');
    assert(
        NFTMint.get_token_stat(token_id1, 0) == Stat { stat_type: 'birthplace1', value: 111 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 1) == Stat { stat_type: 'ethnicity2', value: 222 },
        'Error:: stat'
    );
    assert(
        NFTMint.get_token_stat(token_id1, 2) == Stat { stat_type: 'occupation3', value: 333 },
        'Error:: stat'
    );

    let mut stats2 = ArrayTrait::<Stat>::new();
    stats2.append(Stat { stat_type: 'str', value: 1 });
    stats2.append(Stat { stat_type: 'damage', value: 2 });
    stats2.append(Stat { stat_type: 'age', value: 3 });
    stats2.append(Stat { stat_type: 'int', value: 4 });
    stats2.append(Stat { stat_type: 'ability', value: 5 });

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.update_token_stats(token_id1, stats2.span());

    assert(NFTMint.get_token_stat_len(token_id1) == 5, 'Error:: stat len');
    assert(NFTMint.get_token_stat(token_id1, 0) == *stats2.at(0), 'Error:: stat');
    assert(NFTMint.get_token_stat(token_id1, 1) == *stats2.at(1), 'Error:: stat');
    assert(NFTMint.get_token_stat(token_id1, 2) == *stats2.at(2), 'Error:: stat');
    assert(NFTMint.get_token_stat(token_id1, 3) == *stats2.at(3), 'Error:: stat');
    assert(NFTMint.get_token_stat(token_id1, 4) == *stats2.at(4), 'Error:: stat');
}

#[test]
#[should_panic(expected: ('Free mint has not started',))]
fn test_whitelist_mint_not_started_then_panices() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(3));
    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);
}


#[test]
#[should_panic(expected: ('Public sale has not started',))]
fn test_multi_mint_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
    NFTMint.set_free_mint(true);

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(3));
    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);

    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);
}


#[test]
#[should_panic(expected: ('Address already whitelisted',))]
fn test_already_whitelisted_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
    NFTMint.add_whitelist_addresses(array![_OWNER,]);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_not_owner_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
}


#[test]
#[should_panic(expected: ('Public sale has not started',))]
fn test_sale_not_started_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
    NFTMint.set_free_mint(true);

    let mut i = 1_u32;
    while i < 102 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);

        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint
        .mint(
            contract_address_try_from_felt252(1.into()).unwrap(), 1, ETHContract.contract_address
        );
}


#[test]
#[should_panic(expected: ('User whitelist limit reached',))]
fn test_wl_mint_limit_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1, _ACCOUNT2, _ACCOUNT3]);
    NFTMint.set_free_mint(true);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_whitelist_addresses(array![_ACCOUNT1,]);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.mint(_ACCOUNT1, 1, ETHContract.contract_address);
}


#[test]
#[should_panic(expected: ('User mint limit reached',))]
fn test_sale_limit_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ACCOUNT4: ContractAddress = contract_address_const::<'account4'>();
    let (ETHContract, _STRKContract, _LORDSContract) = deploy_tokens(
        _OWNER, ETH_ADDRESS.try_into().unwrap()
    );

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(3));
    ETHContract.transfer(_ACCOUNT1, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT2, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT3, 1000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 1000 * MINTING_FEE);
    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT1, 21, ETHContract.contract_address);
}

#[test]
#[should_panic(expected: ('User mint limit reached',))]
fn test_sale_limit2_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ACCOUNT4: ContractAddress = contract_address_const::<'account4'>();
    let (ETHContract, _STRKContract, _LORDSContract) = deploy_tokens(
        _OWNER, ETH_ADDRESS.try_into().unwrap()
    );

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(3));
    ETHContract.transfer(_ACCOUNT1, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT2, 1000 * MINTING_FEE);
    ETHContract.transfer(_ACCOUNT3, 1000 * MINTING_FEE);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    cheat_caller_address(ETHContract.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 1000 * MINTING_FEE);
    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(2));

    let owner_balance = ETHContract.balance_of(_OWNER);

    NFTMint.mint(_ACCOUNT1, 10, ETHContract.contract_address);

    assert(ETHContract.balance_of(_ACCOUNT1) == 990 * MINTING_FEE, 'Error:: balanceOf ac1');
    assert(
        ETHContract.balance_of(_OWNER) == owner_balance + 10 * MINTING_FEE,
        'Error:: balanceOf owner'
    );
    NFTMint.mint(_ACCOUNT1, 11, ETHContract.contract_address);
}


#[test]
#[should_panic(expected: ('Invalid fee token',))]
fn test_invalid_sale_token_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let (ETHContract, STRKContract, _LORDSContract) = deploy_tokens(
        _OWNER, ETH_ADDRESS.try_into().unwrap()
    );

    let NFTMint = deploy(_OWNER);
    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    let mut i = 1_u32;
    while i < 101 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT1, 2, STRKContract.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid proof',))]
fn test_invalid_proof_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_merkle_root(MERKLE_ROOT);

    assert(NFTMint.get_merkle_root() == MERKLE_ROOT, 'Error:: saved root');

    let token_id1: u256 = 1;
    let name1 = 'Theseusides';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'West Macedonia' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Macedonians' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
        0x8c716ef984c8f0d28eaeb3953cbe744fd801666fc72b6ba76ab73783ffe7e7,
        0x1ea5f6c1e9b55ab8c90c0ec054bd26e73cd2315c321cf8ebc6dcfe6825996a3,
        0x3269866fed3f1037dd0842c0377789813059a5f161408cf69540a545b5b98f7,
        0x670931d08fd6143ff56c710e7133b3772beac178ce5e94f4c2fc46752212690,
        0x418ef66924acf7ee380515d2d9403cc6305eb8591b2f13eb089b78535e86719,
        0x7e006e3e813a9c414b5319e8000bb9ff236cc0f3d9df5bf93e3bd3bcf5590c8,
        0x56cfa47a8c941147f8d668abc703883d9bce3d629b5a25641578f06ba633945
    ];

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.reveal_token(token_id1, name1, attributes1.span(), proof1.span());
}

#[test]
#[should_panic(expected: ('Token already revealed',))]
fn test_already_reveal_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_merkle_root(MERKLE_ROOT);

    assert(NFTMint.get_merkle_root() == MERKLE_ROOT, 'Error:: saved root');

    let token_id1: u256 = 1;
    let name1 = 'Theseusides';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'West Macedonia' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Macedonians' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
        0x8c716ef984c8f0d28eaeb3953cbe744fd801666fc72b6ba76ab73783ffe7e7,
        0x1ea5f6c1e9b55ab8c90c0ec054bd26e73cd2315c321cf8ebc6dcfe6825996a3,
        0x3269866fed3f1037dd0842c0377789813059a5f161408cf69540a545b5b98f7,
        0x670931d08fd6143ff56c710e7133b3772beac178ce5e94f4c2fc46752212690,
        0x418ef66924acf7ee380515d2d9403cc6305eb8591b2f13eb089b78535e86719,
        0x7e006e3e813a9c414b5319e8000bb9ff236cc0f3d9df5bf93e3bd3bcf5590c8,
        0x56cfa47a8c941147f8d668abc703883d9bce3d629b5a25641578f06ba633948
    ];
    assert(
        NFTMint
            .get_root_for(name1, token_id1.low, attributes1.span(), proof1.span()) == MERKLE_ROOT,
        'Error:: token1 data'
    );

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.reveal_token(token_id1, name1, attributes1.span(), proof1.span());
    NFTMint.reveal_token(token_id1, name1, attributes1.span(), proof1.span());
}


#[test]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_not_owner_reveal_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_merkle_root(MERKLE_ROOT);

    assert(NFTMint.get_merkle_root() == MERKLE_ROOT, 'Error:: saved root');

    let token_id1: u256 = 1;
    let name1 = 'Theseusides';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'West Macedonia' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Macedonians' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
        0x8c716ef984c8f0d28eaeb3953cbe744fd801666fc72b6ba76ab73783ffe7e7,
        0x1ea5f6c1e9b55ab8c90c0ec054bd26e73cd2315c321cf8ebc6dcfe6825996a3,
        0x3269866fed3f1037dd0842c0377789813059a5f161408cf69540a545b5b98f7,
        0x670931d08fd6143ff56c710e7133b3772beac178ce5e94f4c2fc46752212690,
        0x418ef66924acf7ee380515d2d9403cc6305eb8591b2f13eb089b78535e86719,
        0x7e006e3e813a9c414b5319e8000bb9ff236cc0f3d9df5bf93e3bd3bcf5590c8,
        0x56cfa47a8c941147f8d668abc703883d9bce3d629b5a25641578f06ba633948
    ];
    assert(
        NFTMint
            .get_root_for(name1, token_id1.low, attributes1.span(), proof1.span()) == MERKLE_ROOT,
        'Error:: token1 data'
    );

    cheat_caller_address(NFTMint.contract_address, _ACCOUNT1, CheatSpan::TargetCalls(1));
    NFTMint.reveal_token(token_id1, name1, attributes1.span(), proof1.span());
}

#[test]
#[should_panic(expected: ('Invalid stat proof',))]
fn test_invalid_proof_stat_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let _ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());
    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.add_authorized_address(_OWNER);

    let token_id1: u256 = 1;
    let mut stats = ArrayTrait::<Stat>::new();
    stats.append(Stat { stat_type: 'birthplace1', value: 111 });
    stats.append(Stat { stat_type: 'ethnicity2', value: 222 });
    stats.append(Stat { stat_type: 'occupation3', value: 333 });

    let proof1 = array![
        0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898b8208,
        0x7cb9f7e626f51df2323aa4f7b04fad91b148c0c79029faca0898edd9c449ef,
        0x456ce991eab61b455527dc34cc71c39458b0000cf75065344e15747e4a147c8,
        0x2b59f1b6509226b9d8ad9b694693948cddcc73741293d0a302738a707b5acd0,
    ];

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.set_stat_merkle_root(0x4b3133c06a5497f1f54e77a87dec7c8e26720a15fd889d99f97f880898);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.reveal_stats(token_id1, stats.span(), proof1.span());
}

#[test]
#[should_panic(expected: ('Max public mint reached',))]
fn test_mint_limit_when_wl_not_finished_then_panics() {
    let (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3) = deploy_accounts();

    let ETHContract = deploy_token(_OWNER, ETH_ADDRESS.try_into().unwrap());

    let NFTMint = deploy(_OWNER);

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_free_mint(true);
    NFTMint.set_public_sale_open(true);

    cheat_caller_address(ETHContract.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    ETHContract.approve(NFTMint.contract_address, 10000 * MINTING_FEE);

    let mut i = 1_u32;
    while i < 21 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .add_whitelist_addresses(array![contract_address_try_from_felt252(i.into()).unwrap()]);

        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
        NFTMint
            .mint(
                contract_address_try_from_felt252(i.into()).unwrap(),
                1,
                ETHContract.contract_address
            );
        i += 1;
    };

    assert(NFTMint.get_whitelisted_token_minted() == 20, 'Error:: wl minted');
    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 21, 'Error:: total sup');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(2));
    NFTMint.set_whitelist_limit(900);

    let mut j = 1_u32;
    while j < 6 {
        cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
        NFTMint
            .mint(
                contract_address_try_from_felt252((j * 222).into()).unwrap(),
                20,
                ETHContract.contract_address
            );
        j += 1;
    };

    assert(NFTMint.total_supply() == OWNER_FREE_MINT_AMOUNT + 121, 'Error:: total sup2');
    assert(NFTMint.get_whitelisted_token_minted() == 20, 'Error:: wl minted');

    cheat_caller_address(NFTMint.contract_address, _OWNER, CheatSpan::TargetCalls(1));
    NFTMint.mint(_ACCOUNT2, 1, ETHContract.contract_address);
}


//

fn deploy_accounts() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let _OWNER: ContractAddress = contract_address_const::<'factory_owner'>();
    let _ACCOUNT1: ContractAddress = contract_address_const::<'account1'>();
    let _ACCOUNT2: ContractAddress = contract_address_const::<'account2'>();
    let _ACCOUNT3: ContractAddress = contract_address_const::<'account3'>();
    (_OWNER, _ACCOUNT1, _ACCOUNT2, _ACCOUNT3)
}


fn deploy(admin: ContractAddress) -> INFTMintDispatcher {
    let mut calldata = ArrayTrait::new();
    calldata.append(contract_address_to_felt252(admin));
    let contract = declare("NFTMint").unwrap();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    INFTMintDispatcher { contract_address: contract_address }
}

fn deploy_token(recipient: ContractAddress, contractAdd: ContractAddress) -> ERC20ABIDispatcher {
    let mut calldata = ArrayTrait::new();

    calldata.append(1000000000000000000);
    calldata.append(1111);
    calldata.append(recipient.into());
    let contract = declare("ERC20Mock").unwrap();
    let (contract_address, _) = contract.deploy_at(@calldata, contractAdd).unwrap();
    ERC20ABIDispatcher { contract_address: contract_address }
}

fn deploy_tokens(
    recipient: ContractAddress, contractAdd: ContractAddress
) -> (ERC20ABIDispatcher, ERC20ABIDispatcher, ERC20ABIDispatcher) {
    let mut calldata = ArrayTrait::new();

    calldata.append(TOKEN_SUPPLY_F);
    calldata.append(0);
    calldata.append(recipient.into());
    let contract = declare("ERC20Mock").unwrap();
    let strk = contract_address_const::<'strk'>();
    let lords = contract_address_const::<'lords'>();

    let (contract_address, _) = contract.deploy_at(@calldata, contractAdd).unwrap();
    let (strk_address, _) = contract.deploy_at(@calldata, strk).unwrap();
    let (lords_address, _) = contract.deploy_at(@calldata, lords).unwrap();

    (
        ERC20ABIDispatcher { contract_address: contract_address },
        ERC20ABIDispatcher { contract_address: strk_address },
        ERC20ABIDispatcher { contract_address: lords_address },
    )
}

