use super::helpers::{shr, shl};
use core::cmp::min;

const alphabet: [u8; 32] = [
    'q', 'p', 'z', 'r', 'y', '9', 'x', '8',
    'g', 'f', '2', 't', 'v', 'd', 'w', '0', 
    's', '3', 'j', 'n', '5', '4', 'k', 'h',
    'c', 'e', '6', 'm', 'u', 'a', '7', 'l'
];

#[inline(always)]
fn polymod(ref chk: u32, value: u8) {
    let top = chk;
    chk = shl((chk & 0x1ffffff_u32), 5) ^ value.into();

    if top & 33554432_u32 != 0 {        // bit 25
        chk = chk ^ 0x3b6a57b2_u32;
    }
    if top & 67108864_u32 != 0 {        // bit 26
        chk = chk ^ 0x26508e6d_u32;
    }
    if top & 134217728_u32 != 0 {       // bit 27
        chk = chk ^ 0x1ea119fa_u32;
    }
    if top & 268435456_u32 != 0 {       // bit 28
        chk = chk ^ 0x3d4233dd_u32;
    }
    if top & 536870912_u32 != 0 {       // bit 29
        chk = chk ^ 0x2a1462b3_u32;
    }
}

fn convert_bytearray_to_bytes(data: @ByteArray) -> Array<u8> {
    let mut r: Array<u8> = ArrayTrait::new();
    let len = data.len();
    let mut i = 0;
    while i != len {
        r.append(data[i]);
        i += 1;
    };
    r
}

fn convert_bytearray_to_5bit_chunks(data: @ByteArray) -> Array<u8> {
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

fn checksum(hrp: Array<u8>, data: @Array<u8>) -> Array<u32> {
    let mut chk = 1_u32;

    for x in hrp.span() {
        polymod(ref chk, shr(*x, 5));
    };
    polymod(ref chk, 0);
    for x in hrp {
        polymod(ref chk, x & 31);
    };

    for x in data.span() {
        polymod(ref chk, *x);
    };

    polymod(ref chk, 0);
    polymod(ref chk, 0);
    polymod(ref chk, 0);
    polymod(ref chk, 0);
    polymod(ref chk, 0);
    polymod(ref chk, 0);
    
    chk = chk ^ 1;

    let mut r = ArrayTrait::new();
    r.append(shr(chk, 25) & 31);
    r.append(shr(chk, 20) & 31);
    r.append(shr(chk, 15) & 31);
    r.append(shr(chk, 10) & 31);
    r.append(shr(chk, 5) & 31);
    r.append(chk & 31);

    r
}

pub fn encode(hrp: @ByteArray, data: @ByteArray, limit: usize) -> ByteArray {
    let alphabet = alphabet.span();
    let data_5bits = convert_bytearray_to_5bit_chunks(data);
    let hrp_bytes = convert_bytearray_to_bytes(hrp);

    let cs = checksum(hrp_bytes, @data_5bits);

    let mut encoded: ByteArray = hrp.clone();
    encoded.append_byte('1');    
    for x in data_5bits {
        encoded.append_byte(*alphabet[x.into()]);
    };
    for x in cs {
        encoded.append_byte(*alphabet[x]);
    };

    encoded
}
