fn find_word_length(word: felt252) -> u32 {
    let mut length = 0_u32;
    let mut word_u256: u256 = word.into();
    loop {
        let res = word_u256 / 256;
        length = length + 1;

        if (res == 0 || length == 31) {
            break;
        }
        word_u256 = res;
    };
    length
}
