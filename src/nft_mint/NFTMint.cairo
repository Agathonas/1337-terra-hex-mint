#[starknet::contract]
mod NFTMint {
    use core::traits::Into;
    use core::option::OptionTrait;
    use core::array::SpanTrait;
    use openzeppelin::token::erc721::interface::IERC721;
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use openzeppelin::token::erc721::{ERC721Component, interface};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use terracon_prestige_card::errors::Errors;
    use terracon_prestige_card::nft_mint::interface::{
        INFTMint, MAX_MINT_LIMIT, MINTING_FEE, MAX_SUPPLY, OWNER_FREE_MINT_AMOUNT,
        MAX_WHITELIST_MINT
    };
    use core::integer::u128_to_felt252;

    use core::hash::{LegacyHash, HashStateTrait};
    use alexandria_merkle_tree::merkle_tree::{
        Hasher, MerkleTree, pedersen::PedersenHasherImpl, MerkleTreeTrait
    };
    use core::poseidon::{poseidon_hash_span, hades_permutation};

    use terracon_prestige_card::types::{TokenMetadata, Attribute, Stat};
    use terracon_prestige_card::utils::{find_word_length};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        public_sale_open: bool,
        free_mint_open: bool,
        merkle_root: felt252,
        stats_merkle_root: felt252,
        next_token_id: u256,
        whitelisted_address: LegacyMap::<u32, ContractAddress>,
        whitelisted_address_len: u32,
        is_whitelisted: LegacyMap::<ContractAddress, bool>,
        // (owner,index)-> token_id
        owned_tokens: LegacyMap::<(ContractAddress, u256), u256>,
        owned_tokens_len: LegacyMap::<ContractAddress, u256>,
        token_metadata: LegacyMap<u256, TokenMetadata>,
        token_attributes: LegacyMap<(u256, u32), Attribute>,
        token_attributes_len: LegacyMap<u256, u32>,
        token_stats: LegacyMap<(u256, u32), Stat>,
        token_stats_len: LegacyMap<u256, u32>,
        is_revealed: LegacyMap<u256, bool>,
        is_stat_revealed: LegacyMap<u256, bool>,
        authorized_addresses: LegacyMap<ContractAddress, bool>,
        payment_tokens: LegacyMap<ContractAddress, u256>,
        whitelist_mint: LegacyMap<ContractAddress, u256>,
        public_mint: LegacyMap<ContractAddress, u256>,
        whitelisted_max_amount: u256,
        whitelisted_token_minted: u256,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PublicSaleOpen: PublicSaleOpen,
        FreeMintOpen: FreeMintOpen,
        PublicSaleClose: PublicSaleClose,
        AddAuthAddress: AddAuthAddress,
        RemoveAuthAddress: RemoveAuthAddress,
        UpdateTokenAtributes: UpdateTokenAtributes,
        UpdateTokenStats: UpdateTokenStats,
        WhitelistAddress: WhitelistAddress,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct PublicSaleOpen {
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct FreeMintOpen {
        time: u64
    }


    #[derive(Drop, starknet::Event)]
    struct PublicSaleClose {
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct AddAuthAddress {
        address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct RemoveAuthAddress {
        address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateTokenAtributes {
        token_id: u256,
        attributes: Span::<Attribute>
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateTokenStats {
        token_id: u256,
        stats: Span::<Stat>
    }

    #[derive(Drop, starknet::Event)]
    struct WhitelistAddress {
        address: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name = format!("Terracon Hex Prestige Card");
        let symbol = format!("HEX");

        self.erc721.initializer(name, symbol, format!(""));
        /// @dev Set the initial owner of the contract
        self.ownable.initializer(owner);

        /// @dev Mint the initial tokens for the contract owner
        let mut token_id = 1;
        while token_id <= OWNER_FREE_MINT_AMOUNT {
            self._add_token_to(owner, token_id);
            self.erc721._mint(owner, token_id);
            token_id += 1;
        };
        self.next_token_id.write(token_id);
        self.whitelisted_max_amount.write(200);
        self
            .payment_tokens
            .write(
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 // ETH Contract Address
                    .try_into()
                    .unwrap(),
                MINTING_FEE
            );
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of interface::IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_metadata.read(token_id).external_url
        }
    }

    #[abi(embed_v0)]
    impl ERC721Impl of interface::IERC721<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), ERC721Component::Errors::INVALID_ACCOUNT);
            self.erc721.ERC721_balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721._owner_of(token_id)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(
                self.erc721._is_approved_or_owner(get_caller_address(), token_id),
                ERC721Component::Errors::UNAUTHORIZED
            );
            self._remove_token_from(from, token_id);
            self._add_token_to(to, token_id);
            self.erc721._safe_transfer(from, to, token_id, data);
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(
                self.erc721._is_approved_or_owner(get_caller_address(), token_id),
                ERC721Component::Errors::UNAUTHORIZED
            );
            self._remove_token_from(from, token_id);
            self._add_token_to(to, token_id);
            self.erc721._transfer(from, to, token_id);
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self.erc721._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || self.is_approved_for_all(owner, caller),
                ERC721Component::Errors::UNAUTHORIZED
            );
            self.erc721._approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self.erc721._set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            self.erc721.ERC721_token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.erc721.ERC721_operator_approvals.read((owner, operator))
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl of interface::IERC721CamelOnly<ContractState> {
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.owner_of(tokenId)
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            self.safe_transfer_from(from, to, tokenId, data);
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            self.transfer_from(from, to, tokenId);
        }

        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            self.set_approval_for_all(operator, approved)
        }

        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.get_approved(tokenId)
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.is_approved_for_all(owner, operator)
        }
    }


    #[abi(embed_v0)]
    impl NFTMint of INFTMint<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.next_token_id.read()
        }

        fn token_of_owner_by_index(
            self: @ContractState, user: ContractAddress, index: u256
        ) -> u256 {
            self.owned_tokens.read((user, index))
        }

        fn token_of_owner_by_index_len(self: @ContractState, user: ContractAddress,) -> u256 {
            self.owned_tokens_len.read(user,)
        }

        fn get_token_metadata(self: @ContractState, token_id: u256,) -> TokenMetadata {
            self.token_metadata.read(token_id,)
        }

        fn get_token_attribute(self: @ContractState, token_id: u256, index: u32) -> Attribute {
            self.token_attributes.read((token_id, index))
        }

        fn get_token_attribute_len(self: @ContractState, token_id: u256) -> u32 {
            self.token_attributes_len.read(token_id,)
        }

        fn get_token_attributes(self: @ContractState, token_id: u256) -> Array<Attribute> {
            let attributes_len = self.token_attributes_len.read(token_id,);
            let mut attributes: Array<Attribute> = ArrayTrait::new();
            let mut i = 0;
            while i < attributes_len {
                attributes.append(self.token_attributes.read((token_id, i)));
                i = i + 1;
            };
            attributes
        }

        fn get_token_stat(self: @ContractState, token_id: u256, index: u32) -> Stat {
            self.token_stats.read((token_id, index))
        }

        fn get_token_stat_len(self: @ContractState, token_id: u256) -> u32 {
            self.token_stats_len.read(token_id,)
        }

        fn get_token_stats(self: @ContractState, token_id: u256) -> Array<Stat> {
            let len = self.token_stats_len.read(token_id,);
            let mut stats: Array<Stat> = ArrayTrait::new();
            let mut i = 0;
            while i < len {
                stats.append(self.token_stats.read((token_id, i)));
                i = i + 1;
            };
            stats
        }


        fn is_revealed(self: @ContractState, token_id: u256,) -> bool {
            self.is_revealed.read(token_id,)
        }

        fn is_stats_revealed(self: @ContractState, token_id: u256,) -> bool {
            self.is_stat_revealed.read(token_id,)
        }

        fn is_authorized(self: @ContractState, address: ContractAddress) -> bool {
            self.authorized_addresses.read(address)
        }

        fn public_sale_open(self: @ContractState,) -> bool {
            self.public_sale_open.read()
        }

        fn free_mint_open(self: @ContractState,) -> bool {
            self.free_mint_open.read()
        }

        fn is_whitelisted(self: @ContractState, user: ContractAddress) -> bool {
            self.is_whitelisted.read(user)
        }

        fn all_whitelist_addresses(self: @ContractState,) -> Array<ContractAddress> {
            let whitelist_len = self.whitelisted_address_len.read();
            let mut whitelist: Array<ContractAddress> = ArrayTrait::new();
            let mut i = 0;
            while i < whitelist_len {
                whitelist.append(self.whitelisted_address.read(i));
                i = i + 1;
            };
            whitelist
        }

        fn mint_fee(self: @ContractState, token: ContractAddress) -> u256 {
            self.payment_tokens.read(token)
        }

        fn get_root_for(
            self: @ContractState,
            name: felt252,
            tokenId: u128,
            mut attributes: Span::<Attribute>,
            proof: Span::<felt252>
        ) -> felt252 {
            let mut merkle_tree: MerkleTree<Hasher> = MerkleTreeTrait::new();
            let mut data = ArrayTrait::<felt252>::new();

            data.append(tokenId.into());
            data.append(name);

            loop {
                match attributes.pop_front() {
                    Option::Some(attribute) => {
                        data.append(*attribute.trait_type);
                        data.append(*attribute.value);
                    },
                    Option::None => { break; }
                };
            };

            let leaf = poseidon_hash_span(data.span());
            merkle_tree.compute_root(leaf, proof)
        }

        fn get_stat_root_for(
            self: @ContractState, tokenId: u128, mut stats: Span::<Stat>, proof: Span::<felt252>
        ) -> felt252 {
            let mut merkle_tree: MerkleTree<Hasher> = MerkleTreeTrait::new();
            let mut data = ArrayTrait::<felt252>::new();

            data.append(tokenId.into());
            loop {
                match stats.pop_front() {
                    Option::Some(stat) => {
                        data.append(*stat.stat_type);
                        data.append(u128_to_felt252(*stat.value.low));
                    },
                    Option::None => { break; }
                };
            };

            let leaf = poseidon_hash_span(data.span());
            merkle_tree.compute_root(leaf, proof)
        }


        fn get_merkle_root(ref self: ContractState,) -> felt252 {
            self.merkle_root.read()
        }


        fn get_stat_merke_root(ref self: ContractState,) -> felt252 {
            self.stats_merkle_root.read()
        }

        fn get_whitelisted_token_minted(ref self: ContractState,) -> u256 {
            self.whitelisted_token_minted.read()
        }

        fn get_whitelisted_max_amount(ref self: ContractState,) -> u256 {
            self.whitelisted_max_amount.read()
        }

        fn add_authorized_address(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_addresses.write(address, true);
            self.emit(Event::AddAuthAddress(AddAuthAddress { address: address }));
        }

        fn remove_authorized_address(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_addresses.write(address, false);
            self.emit(Event::RemoveAuthAddress(RemoveAuthAddress { address: address }));
        }


        fn set_payment_tokens(ref self: ContractState, token: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            assert(amount != 0, Errors::INVALID_FEE_AMOUNT);
            self.payment_tokens.write(token, amount);
        }


        fn set_whitelist_limit(ref self: ContractState, amount: u256) {
            self.ownable.assert_only_owner();
            assert(amount >= self.whitelisted_token_minted.read(), Errors::INVALID_MINT_LIMIT);
            self.whitelisted_max_amount.write(amount);
        }

        fn update_token_attributes(
            ref self: ContractState, token_id: u256, mut new_attributes: Span::<Attribute>,
        ) {
            assert(self.is_authorized(get_caller_address()), Errors::NOT_AUTHORIZED);
            let attributes_len = new_attributes.len();
            let mut index = 0;
            loop {
                match new_attributes.pop_front() {
                    Option::Some(attribute) => {
                        self.token_attributes.write((token_id, index), *attribute);
                        index = index + 1;
                    },
                    Option::None => { break; }
                };
            };
            self.token_attributes_len.write(token_id, attributes_len);
            self
                .emit(
                    Event::UpdateTokenAtributes(
                        UpdateTokenAtributes { token_id: token_id, attributes: new_attributes }
                    )
                );
        }

        fn update_token_stats(
            ref self: ContractState, token_id: u256, mut new_stats: Span::<Stat>,
        ) {
            assert(self.is_authorized(get_caller_address()), Errors::NOT_AUTHORIZED);
            let stats_len = new_stats.len();
            let mut index = 0;
            loop {
                match new_stats.pop_front() {
                    Option::Some(stat) => {
                        self.token_stats.write((token_id, index), *stat);
                        index = index + 1;
                    },
                    Option::None => { break; }
                };
            };
            self.token_stats_len.write(token_id, stats_len);
            self
                .emit(
                    Event::UpdateTokenStats(
                        UpdateTokenStats { token_id: token_id, stats: new_stats }
                    )
                );
        }

        fn mint(
            ref self: ContractState,
            recipient: ContractAddress,
            quantity: u256,
            fee_token: ContractAddress
        ) {
            assert(!recipient.is_zero(), Errors::INVALID_RECIPIENT);
            let next_token_id = self.next_token_id.read();
            assert(next_token_id + quantity <= MAX_SUPPLY, Errors::MAX_SUPPLY_REACHED);

            let whitelisted_max = self.whitelisted_max_amount.read();
            let whitelist_minted = self.whitelisted_token_minted.read();

            let mut token_id = next_token_id;
            let mut minted_quantity = 0;

            let whitelisted = self.is_whitelisted.read(recipient);

            let public_mint_amount = self.public_mint.read(recipient);

            assert(public_mint_amount + quantity <= MAX_MINT_LIMIT, Errors::MINT_REACHED);

            while minted_quantity < quantity {
                if whitelisted && whitelist_minted < whitelisted_max {
                    assert(self.free_mint_open.read(), Errors::FREE_MINT_NOT_STARTED);
                    /// @dev Check if the recipient is whitelisted
                    assert(quantity == MAX_WHITELIST_MINT, Errors::WHITELIST_LIMIT);
                    assert(
                        self.whitelist_mint.read(recipient) == 0, Errors::WHITELISTED_MINT_REACHED
                    );

                    let mut whitelist_len = self.whitelisted_address_len.read();
                    whitelist_len = self._remove_whitelist(recipient, whitelist_len);
                    self.whitelisted_address_len.write(whitelist_len);
                    self._add_token_to(recipient, token_id);
                    self.erc721._mint(recipient, token_id);
                    self.whitelist_mint.write(recipient, 1);
                    self.whitelisted_token_minted.write(whitelist_minted + 1);
                } else {
                    /// @dev Check if the public sale is open
                    assert(self.public_sale_open.read(), Errors::PUBLIC_SALE_NOT_STARTED);
                    let mint_fee = self.payment_tokens.read(fee_token);

                    assert(mint_fee != 0, Errors::INVALID_FEE_TOKEN);
                    let token_dispatcher = ERC20ABIDispatcher { contract_address: fee_token };
                    let success = token_dispatcher
                        .transferFrom(get_caller_address(), self.ownable.owner(), mint_fee);
                    assert(success, Errors::TRANSFER_FAILED);

                    self._add_token_to(recipient, token_id);
                    self.erc721._mint(recipient, token_id);
                }
                token_id += 1;
                minted_quantity += 1;
            };
            let whitelist_minted_ = self.whitelisted_token_minted.read();
            let whitelist_left = whitelisted_max - whitelist_minted_;

            assert(token_id - 1 + whitelist_left <= MAX_SUPPLY, Errors::MAX_PUBLIC_MINT_REACHED);

            self.public_mint.write(recipient, minted_quantity);
            self.next_token_id.write(token_id);
        }

        fn reveal_token(
            ref self: ContractState,
            token_id: u256,
            name: felt252,
            mut attributes: Span::<Attribute>,
            proofs: Span::<felt252>
        ) {
            assert(!self.is_revealed(token_id), Errors::TOKEN_ALREADY_REVALED);
            let owner = self.erc721.owner_of(token_id);
            let caller = get_caller_address();
            assert(owner == caller, ERC721Component::Errors::UNAUTHORIZED);

            let root = self.get_root_for(name, token_id.low, attributes, proofs);
            assert(root == self.merkle_root.read(), Errors::INVALID_PROOF);

            let mut nameByte = format!("");
            let name_len = find_word_length(name);
            nameByte.append_word(name, name_len);

            let mut description = format!("");
            description.append_word(name, name_len);
            description.append(@format!(" is a character from Terracon Quest Autonomous World."));

            let mut url = format!("https://terracon.quest/");
            url.append_word(name, name_len);

            let metadata = TokenMetadata {
                name: nameByte,
                description: description,
                image: format!(
                    "https://terraconquest.mypinata.cloud/ipfs/QmUysuKZyMwoqPgdEatwc51HQCMqvjf2z7CmoHAqgtbWMD/{}.png",
                    token_id
                ),
                external_url: url,
            };

            self.token_metadata.write(token_id, metadata);

            let attributes_len = attributes.len();
            let mut index = 0;

            loop {
                match attributes.pop_front() {
                    Option::Some(attribute) => {
                        self.token_attributes.write((token_id, index), *attribute);
                        index = index + 1;
                    },
                    Option::None => { break; }
                };
            };
            self.token_attributes_len.write(token_id, attributes_len);
            self.is_revealed.write(token_id, true);
        }

        fn reveal_stats(
            ref self: ContractState,
            token_id: u256,
            mut stats: Span::<Stat>,
            proofs: Span::<felt252>
        ) {
            let root = self.get_stat_root_for(token_id.low, stats, proofs);
            assert(root == self.stats_merkle_root.read(), Errors::INVALID_STAT_PROOF);
            let stats_len = stats.len();
            let mut index = 0;

            loop {
                match stats.pop_front() {
                    Option::Some(stat) => {
                        self.token_stats.write((token_id, index), *stat);
                        index = index + 1;
                    },
                    Option::None => { break; }
                };
            };
            self.token_stats_len.write(token_id, stats_len);
            self.is_stat_revealed.write(token_id, true);
        }


        fn set_public_sale_open(ref self: ContractState, public_sale_open: bool) {
            self.ownable.assert_only_owner();
            self.public_sale_open.write(public_sale_open);

            let current_time = get_block_timestamp();
            if public_sale_open {
                self.emit(Event::PublicSaleOpen(PublicSaleOpen { time: current_time }));
            } else {
                self.emit(Event::PublicSaleClose(PublicSaleClose { time: current_time }));
            };
        }

        fn set_free_mint(ref self: ContractState, mint_open: bool) {
            self.ownable.assert_only_owner();
            self.free_mint_open.write(mint_open);
            let current_time = get_block_timestamp();
            if mint_open {
                self.emit(Event::FreeMintOpen(FreeMintOpen { time: current_time }));
            }
        }

        fn set_merkle_root(ref self: ContractState, root: felt252) {
            self.ownable.assert_only_owner();
            self.merkle_root.write(root);
        }

        fn set_stat_merkle_root(ref self: ContractState, root: felt252) {
            self.ownable.assert_only_owner();
            self.stats_merkle_root.write(root);
        }

        fn add_whitelist_addresses(ref self: ContractState, address_list: Array<ContractAddress>) {
            self.ownable.assert_only_owner();
            let whitelist_len = self.whitelisted_address_len.read();
            self._add_whitelist(address_list, whitelist_len);
        }

        fn remove_whitelist_addresses(
            ref self: ContractState, address_list: Array<ContractAddress>
        ) {
            self.ownable.assert_only_owner();
            let mut whitelist_len = self.whitelisted_address_len.read();
            let mut i = 0;
            while (i < address_list.len()) {
                whitelist_len = self._remove_whitelist(*address_list[i], whitelist_len);
                i += 1;
            };
            self.whitelisted_address_len.write(whitelist_len);
        }
    }


    /// @dev Internal Functions implementation for the NFT Mint contract
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _add_token_to(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owned_len = self.owned_tokens_len.read(to);
            self.owned_tokens.write((to, owned_len), token_id);
            self.owned_tokens_len.write(to, owned_len + 1);
        }

        fn _remove_token_from(ref self: ContractState, from: ContractAddress, token_id: u256) {
            let owned_len = self.owned_tokens_len.read(from);
            let mut i = 0;
            loop {
                if (i == owned_len) {
                    break;
                }
                if token_id == self.owned_tokens.read((from, i)) {
                    let last = self.owned_tokens.read((from, owned_len - 1));
                    self.owned_tokens.write((from, i), last);
                    self.owned_tokens.write((from, owned_len - 1), Zeroable::zero());
                    self.owned_tokens_len.write(from, owned_len - 1);
                    break;
                }
                i = i + 1;
            };
        }

        /// @dev Registers the address and initializes their whitelist status to true (can mint)
        fn _add_whitelist(
            ref self: ContractState, address_list: Array<ContractAddress>, whitelist_len: u32
        ) {
            let mut i = 0;
            while (i < address_list.len()) {
                let address = *address_list[i];
                assert(self.is_whitelisted.read(address) == false, Errors::ALREADY_WHITELISTED);
                self.whitelisted_address.write(whitelist_len + i, address);
                self.is_whitelisted.write(*address_list[i], true);
                self.emit(Event::WhitelistAddress(WhitelistAddress { address: address }));
                i += 1;
            };
            self.whitelisted_address_len.write(whitelist_len + i);
        }

        fn _remove_whitelist(
            ref self: ContractState, address: ContractAddress, whitelist_len: u32
        ) -> u32 {
            let mut i = 0;
            loop {
                if (i == whitelist_len) {
                    break whitelist_len;
                }
                if (address == self.whitelisted_address.read(i)) {
                    let last_address = self.whitelisted_address.read(whitelist_len - 1);
                    self.whitelisted_address.write(i, last_address);
                    self.whitelisted_address.write(whitelist_len - 1, Zeroable::zero());
                    self.is_whitelisted.write(address, false);
                    break whitelist_len - 1;
                }
                i += 1;
            }
        }
    }
}
