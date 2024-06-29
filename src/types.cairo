#[derive(Drop, Serde, starknet::Store, Copy, PartialEq)]
struct Attribute {
    trait_type: felt252,
    value: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct TokenMetadata {
    name: ByteArray,
    description: ByteArray,
    image: ByteArray,
    external_url: ByteArray,
}

#[derive(Drop, Serde, starknet::Store, Copy, PartialEq)]
struct Stat {
    stat_type: felt252,
    value: u256,
}
