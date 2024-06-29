use csv::{ReaderBuilder, WriterBuilder};
use hex;
use starknet_crypto::{pedersen_hash, poseidon_hash_many, FieldElement};
use std::{collections::HashSet, error::Error, str::FromStr};
use dotenv::dotenv;

#[derive(Debug, Clone)]
struct Attribute {
    trait_type: FieldElement,
    value: FieldElement,
}

#[derive(Debug, Clone)]
pub struct Token {
    token_id: FieldElement,
    name: FieldElement,
    attributes: Vec<Attribute>,
}

#[derive(Debug, Clone)]
pub struct Node {
    left_child: Option<Box<Node>>,
    right_child: Option<Box<Node>>,
    accessible_token_ids: HashSet<FieldElement>,
    value: FieldElement,
}

#[derive(Debug, Clone)]
pub struct MerkleTree {
    root: Node,
    tokens: Vec<Token>,
}

#[derive(Debug, Clone)]
struct CairoCalldata {
    proof: Vec<String>,
}

impl MerkleTree {
    pub fn new(tokens: Vec<Token>) -> Self {
        if tokens.is_empty() {
            panic!("No data for merkle tree");
        }
        let mut leaves: Vec<Node> = tokens
            .clone()
            .into_iter()
            .map(|a| Node::new_leaf(a))
            .collect();

        // if odd length add a copy of last elem
        if leaves.len() % 2 == 1 {
            leaves.push(leaves.last().unwrap().clone());
        }

        let root = build_tree(leaves);

        MerkleTree { root, tokens }
    }

    pub fn token_calldata(&self, token_id: u128) -> Result<CairoCalldata, String> {
        let felt_token_id = FieldElement::from(token_id);

        if !&self.root.accessible_token_ids.contains(&felt_token_id) {
            return Err("Token ID not found in tree".to_string());
        }
        let mut hashes: Vec<FieldElement> = vec![];
        let mut current_node = &self.root;
        // if either child is_some, then both is_some
        loop {
            let left = current_node.left_child.as_ref().unwrap();
            let right = current_node.right_child.as_ref().unwrap();
            if left.accessible_token_ids.contains(&felt_token_id) {
                hashes.push(right.value);
                current_node = left;
            } else {
                hashes.push(left.value);
                current_node = right;
            }
            if current_node.left_child.is_none() {
                break;
            }
        }
        // reverse to leaf first root last
        hashes = hashes.into_iter().rev().collect();

        let hash_strings = hashes.iter().map(felt_to_b16).collect();

        let calldata = CairoCalldata {
            proof: hash_strings,
        };
        Ok(calldata)
    }
}

impl Node {
    fn new(a: Node, b: Node) -> Self {
        let (left_child, right_child) = if a.value < b.value { (a, b) } else { (b, a) };
        let value = hash(&left_child.value, &right_child.value);
        let mut accessible_token_ids = HashSet::new();
        accessible_token_ids.extend(left_child.accessible_token_ids.clone());
        accessible_token_ids.extend(right_child.accessible_token_ids.clone());

        Node {
            left_child: Some(Box::new(left_child)),
            right_child: Some(Box::new(right_child)),
            accessible_token_ids,
            value,
        }
    }

    fn new_leaf(token: Token) -> Self {
        let token_id = token.token_id;
        let name = token.name;

        let mut values = vec![token.token_id, token.name];
        for attr in token.attributes {
            values.push(attr.trait_type);
            values.push(attr.value);
        }
        let value = poseidon_hash_many(&values);

        Node {
            left_child: None,
            right_child: None,
            accessible_token_ids: vec![token_id].into_iter().collect(),
            value,
        }
    }
}

enum TreeBuilder {
    KeepGoing(Vec<Node>),
    Done(Node),
}

fn build_tree(leaves: Vec<Node>) -> Node {
    match build_tree_recursively(TreeBuilder::KeepGoing(leaves)) {
        TreeBuilder::Done(root) => root,
        _ => unreachable!("Failed building the tree"),
    }
}

fn build_tree_recursively(tree_builder: TreeBuilder) -> TreeBuilder {
    let mut nodes = match tree_builder {
        TreeBuilder::KeepGoing(nodes) => nodes,
        _ => unreachable!("Failed building the tree"),
    };

    let mut next_nodes: Vec<Node> = vec![];

    while !nodes.is_empty() {
        let a = nodes.pop().unwrap();
        let b = nodes.pop().unwrap();
        next_nodes.push(Node::new(a, b));
    }

    if next_nodes.len() == 1 {
        // return root
        let root = next_nodes.pop().unwrap();
        return TreeBuilder::Done(root);
    }

    if next_nodes.len() % 2 == 1 {
        // if odd - pair last element with itself
        next_nodes.push(next_nodes.last().unwrap().clone());
    }

    build_tree_recursively(TreeBuilder::KeepGoing(next_nodes))
}

pub fn felt_to_b16(felt: &FieldElement) -> String {
    format!("{:#x}", felt)
}

pub fn hash(a: &FieldElement, b: &FieldElement) -> FieldElement {
    if a < b {
        pedersen_hash(a, b)
    } else {
        pedersen_hash(b, a)
    }
}

fn string_to_hex(input: &str) -> String {
    format!("0x{}", hex::encode(input))
}

fn convert_to_felt(input: &str) -> FieldElement {
    FieldElement::from_str(&string_to_hex(input)).unwrap()
}

// Helper function to convert FieldElement to u128
fn field_to_u128(field: &FieldElement) -> Option<u128> {
    let hex_str = field.to_string();
    if hex_str.starts_with("0x") {
        u128::from_str_radix(&hex_str[2..], 16).ok()
    } else {
        u128::from_str_radix(&hex_str, 16).ok()
    }
}

fn read_metadata(file_path: &str) -> Result<Vec<Token>, Box<dyn Error>> {
    let mut tokens: Vec<Token> = Vec::new();
    let mut rdr = ReaderBuilder::new().delimiter(b',').from_path(file_path)?;

    for (i, result) in rdr.records().enumerate() {
        let record = result?;
        println!("CSV Record {}: {:?}", i + 1, record);
        let token_id = FieldElement::from(record[0].parse::<u128>()?);
        let name = convert_to_felt(&record[1]);

        let attributes = vec![
            Attribute {
                trait_type: convert_to_felt("birthplace"),
                value: convert_to_felt(&record[2]),
            },
            Attribute {
                trait_type: convert_to_felt("ethnicity"),
                value: convert_to_felt(&record[3]),
            },
            Attribute {
                trait_type: convert_to_felt("occupation"),
                value: convert_to_felt(&record[4]),
            },
            Attribute {
                trait_type: convert_to_felt("special_trait"),
                value: if record.get(5).is_some() && !record[5].is_empty() {
                    convert_to_felt(&record[5])
                } else {
                    convert_to_felt("None")
                },
            },
        ];

        println!("Read token {}: {:?}", i + 1, token_id);

        tokens.push(Token {
            token_id,
            name,
            attributes,
        });
    }

    Ok(tokens)
}

fn write_metadata_with_proofs(
    file_path: &str,
    tokens: &[Token],
    merkle_tree: &MerkleTree,
) -> Result<(), Box<dyn Error>> {
    let mut wtr = WriterBuilder::new().from_path(file_path)?;
    wtr.write_record(&[
        "token_id",
        "name",
        "birthplace_trait",
        "birthplace_value",
        "ethnicity_trait",
        "ethnicity_value",
        "occupation_trait",
        "occupation_value",
        "special_trait",
        "special_trait_value",
        "merkle_root",
        "proof",
    ])?;

    for (i, token) in tokens.iter().enumerate() {
        let token_id_u128: u128 = token.token_id.try_into().unwrap();
        match merkle_tree.token_calldata(token_id_u128) {
            Ok(calldata) => {
                wtr.write_record(&[
                    format!("{}", token_id_u128),
                    felt_to_b16(&token.name),
                    "birthplace".to_string(),
                    felt_to_b16(&token.attributes[0].value),
                    "ethnicity".to_string(),
                    felt_to_b16(&token.attributes[1].value),
                    "occupation".to_string(),
                    felt_to_b16(&token.attributes[2].value),
                    "special_trait".to_string(),
                    felt_to_b16(&token.attributes[3].value),
                    felt_to_b16(&merkle_tree.root.value),
                    calldata.proof.join(","),
                ])?;
                println!(
                    "Stored token {}: {} with token_id: {:?}",
                    i + 1,
                    felt_to_b16(&token.token_id),
                    token_id_u128
                );
            }
            Err(e) => {

            }
        }
    }

    wtr.flush()?;
    Ok(())
}

fn main() {
    dotenv().ok();
    let tokens = read_metadata("src/metadata_updated.csv").expect("Failed to read metadata");

    let tree = MerkleTree::new(tokens.clone());

    println!("Merkle root: {:?}", tree.root.value);

    write_metadata_with_proofs("src/metadata_with_proofs.csv", &tokens, &tree).expect("Failed to write metadata with proofs");
}