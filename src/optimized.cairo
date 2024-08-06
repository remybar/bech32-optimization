use super::helpers::{shr, shl};
use core::cmp::min;

const alphabet: [u8; 32] = [
    'q', 'p', 'z', 'r', 'y', '9', 'x', '8',
    'g', 'f', '2', 't', 'v', 'd', 'w', '0', 
    's', '3', 'j', 'n', '5', '4', 'k', 'h',
    'c', 'e', '6', 'm', 'u', 'a', '7', 'l'
];

//! bech32 encoding implementation
//! Spec: https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki
//! Sample implementations:
//! https://github.com/sipa/bech32/blob/master/ref/javascript/bech32.js#L86
//! https://github.com/paulmillr/scure-base/blob/main/index.ts#L479

// const GENERATOR: [
//     felt252
//     ; 5] = [
//     1, 2, 3, 4
//     ];

fn polymod(values: Array<u8>) -> u32 {
    let generator = array![
        0x3b6a57b2_u32, 0x26508e6d_u32, 0x1ea119fa_u32, 0x3d4233dd_u32, 0x2a1462b3_u32
    ];
    let generator = generator.span();

    let mut chk = 1_u32;

    let len = values.len();
    let mut p: usize = 0;
    while p != len {
        let top = shr(chk, 25);
        chk = shl((chk & 0x1ffffff_u32), 5) ^ (*values.at(p)).into();
        let mut i = 0_usize;
        while i != 5 {
            if shr(top, i) & 1_u32 != 0 {
                chk = chk ^ *generator.at(i.into());
            }
            i += 1;
        };
        p += 1;
    };

    chk
}

fn hrp_expand(hrp: @Array<u8>, ref values: Array<u8>) {
    let len = hrp.len();
    let mut i = 0;
    while i != len {
        values.append(shr(*hrp.at(i), 5));
        i += 1;
    };
    values.append(0);

    let mut i = 0;
    while i != len {
        values.append(*hrp.at(i) & 31);
        i += 1;
    };
}

fn convert_bytes_to_5bit_chunks(bytes: @Array<u8>) -> Array<u8> {
    let mut r = ArrayTrait::new();

    let len = bytes.len();
    let mut i = 0;

    let mut acc = 0_u8;
    let mut missing_bits = 5_u8;

    while i != len {
        let mut byte: u8 = *bytes.at(i);
        let mut bits_left = 8_u8;
        loop {
            let chunk_size = min(missing_bits, bits_left);
            let chunk = shr(byte, 8 - chunk_size);
            r.append(acc + chunk);
            byte = shl(byte, chunk_size);
            bits_left -= chunk_size;
            if bits_left < 5 {
                acc = shr(byte, 3);
                missing_bits = 5 - bits_left;
                break ();
            } else {
                acc = 0;
                missing_bits = 5
            }
        };
        i += 1;
    };
    if missing_bits < 5 {
        r.append(acc);
    }
    r
}

fn convert_ba_to_bytes(data: @ByteArray) -> Array<u8> {
    let mut r = ArrayTrait::new();
    let len = data.len();
    let mut i = 0;
    while i != len {
        r.append(data[i]);
        i += 1;
    };
    r
}

fn convert_ba_to_5bit_chunks(data: @ByteArray) -> Array<u8> {
    let mut r = ArrayTrait::new();

    let len = data.len();
    let mut i = 0;

    let mut acc = 0_u8;
    let mut missing_bits = 5_u8;

    while i != len {
        let mut byte: u8 = data[i];
        let mut bits_left = 8_u8;
        loop {
            let chunk_size = min(missing_bits, bits_left);
            let chunk = shr(byte, 8 - chunk_size);
            r.append(acc + chunk);
            byte = shl(byte, chunk_size);
            bits_left -= chunk_size;
            if bits_left < 5 {
                acc = shr(byte, 3);
                missing_bits = 5 - bits_left;
                break ();
            } else {
                acc = 0;
                missing_bits = 5
            }
        };
        i += 1;
    };
    if missing_bits < 5 {
        r.append(acc);
    }
    r
}

fn checksum(hrp: @Array<u8>, data: @Array<u8>) -> Array<u8> {
    let mut values = ArrayTrait::new();

    hrp_expand(hrp, ref values);
    values.append_span(data.span());

    values.append(0);
    values.append(0);
    values.append(0);
    values.append(0);
    values.append(0);
    values.append(0);

    let m = polymod(values) ^ 1;

    let mut r = ArrayTrait::new();
    r.append((shr(m, 25) & 31).try_into().unwrap());
    r.append((shr(m, 20) & 31).try_into().unwrap());
    r.append((shr(m, 15) & 31).try_into().unwrap());
    r.append((shr(m, 10) & 31).try_into().unwrap());
    r.append((shr(m, 5) & 31).try_into().unwrap());
    r.append((m & 31).try_into().unwrap());

    r
}

pub fn encode(hrp: @ByteArray, data: @ByteArray, limit: usize) -> ByteArray {
    let alphabet = alphabet.span();
    let data_5bits = convert_ba_to_5bit_chunks(data);
    let hrp_in_bytes = convert_ba_to_bytes(hrp);

    let cs = checksum(@hrp_in_bytes, @data_5bits);

    let mut combined = ArrayTrait::new();
    combined.append_span(data_5bits.span());
    combined.append_span(cs.span());

    let mut encoded: ByteArray = Default::default();
    for x in combined {
        encoded.append_byte(*alphabet[x.into()]);
    };

    format!("{hrp}1{encoded}")
}
