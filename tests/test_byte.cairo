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
use terracon_prestige_card::types::{TokenMetadata, Attribute};

use core::bytes_31::bytes31_to_felt252;
use core::bytes_31::bytes31_try_from_felt252;
use terracon_prestige_card::utils::{find_word_length};

#[test]
fn test_reveal() {
    let name1: felt252 = 'Theseusides';
    let mut attributes1 = ArrayTrait::<Attribute>::new();
    attributes1.append(Attribute { trait_type: 'birthplace', value: 'West Macedonia' });
    attributes1.append(Attribute { trait_type: 'ethnicity', value: 'Macedonians' });
    attributes1.append(Attribute { trait_type: 'occupation', value: 'General' });
    attributes1.append(Attribute { trait_type: 'special_trait', value: 'None' });

    format!("").pending_word.print();
    format!("Theseusides").pending_word.print();

    format!("{}", name1).pending_word.print();

    let mut name = format!("");
    name.append_word(name1, 11);
    name.pending_word.print();

    let mut description = format!("");
    description.append_word(name1, 11);
    description.append(@format!(" is a character from Terracon Quest Autonomous World."));

    assert(name == format!("Theseusides"), 'Error:: name');
    assert(
        description == format!("Theseusides is a character from Terracon Quest Autonomous World."),
        'Error:: 1111name'
    );
    let token = 121234;
    assert(format!("Theseusides {}.", token) == format!("Theseusides 121234."), 'Error:: 1111name');

    let mut url = format!("https://terracon.quest/");
    url.append_word(name1, 11);

    assert(url == format!("https://terracon.quest/Theseusides"), 'Error:: 12');
}

