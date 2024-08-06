use core::array::ArrayTrait;
use core::byte_array::ByteArrayTrait;
use core::cmp::min;
use core::array::ToSpanTrait;
use core::option::OptionTrait;
use core::to_byte_array::FormatAsByteArray;

//! bech32 encoding implementation
use core::traits::{Into, TryInto};

mod optimized;
mod helpers;
mod reference;

#[cfg(test)]
mod tests {
    // test data generated with: https://slowli.github.io/bech32-buffer/

    use super::reference;
    use super::optimized;

    fn measure_ref(hrp: @ByteArray, data: @ByteArray, limit: usize) -> (u128, ByteArray) {
        let start = core::testing::get_available_gas();
        core::gas::withdraw_gas().unwrap();

        let res = reference::encode(hrp, data, limit);

        let end = core::testing::get_available_gas();
        let diff = start - end;
        core::gas::withdraw_gas().unwrap();

        (diff, res)
    }

    fn measure_optimized(hrp: @ByteArray, data: @ByteArray, limit: usize) -> (u128, ByteArray) {
        let start = core::testing::get_available_gas();
        core::gas::withdraw_gas().unwrap();

        let res = optimized::encode(hrp, data, limit);

        let end = core::testing::get_available_gas();
        let diff = start - end;
        core::gas::withdraw_gas().unwrap();

        (diff, res)
    }

    fn compare(name: ByteArray, hrp: @ByteArray, data: @ByteArray, limit: usize) {
        let (gas_ref, res_ref) = measure_ref(hrp, data, limit);
        let (gas_optimized, res_optimized) = measure_optimized(hrp, data, limit);

        if res_ref != res_optimized {
            println!("{name} :: not same result");
        }
        else {
            if gas_ref > gas_optimized {
                let diff = gas_ref - gas_optimized;
                let percent = diff * 100 / gas_ref;
                println!("{name} :: ref: {} optimized: {} diff: -{} ({}%)", gas_ref, gas_optimized, diff, percent);
            }
            else {
                println!("{name} :: ref: {} optimized: {} diff: +{}", gas_ref, gas_optimized, gas_optimized - gas_ref);
            }
        }
    }

    #[test]
    fn test_bech32() {
        compare("sample1", @"abcdef", @"\x00\x00\x00\x00", 90);
        compare("sample2", @"abc", @"\x64\x65\x66", 90);
        compare("sample3", @"abc", @"\x64\x65\x66\x67", 90);
        compare("sample4", @"abc", @"\x01", 90);
        compare("sample5", @"abcd", @"\x01", 90);
        compare("sample6", @"abcd", @"\x00\x00", 90);
        compare("sample7", @"abcd", @"\x00\x00\x00\x00", 90);
        compare("sample8", @"abcdef", @"\x00\x00\x00\x00", 90);
    }
}
