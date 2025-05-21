use std::{fs::File, io::Read, path::Path};

pub fn main() {
    let path = Path::new("01.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let output = process(&input);
    println!("{}", output);
}

fn process(input: &str) -> u32 {
    let iter = input.chars().cycle().skip(1);
    Iterator::zip(input.chars(), iter)
        .filter_map(|(a, b)| if a == b { Some(a) } else { None })
        .map(|c| c as u32 - '0' as u32)
        .sum()
}

#[cfg(test)]
mod tests {
    use crate::process;
    const INPUT: &str = "1122
1111
1234
91212129
";
    const EXPECTATIONS: [u32; 4] = [3, 4, 0, 9];
    #[test]
    fn day_1_1_works() {
        let ok = Iterator::zip(INPUT.lines(), EXPECTATIONS.iter())
            .map(|(line, &expected)| (process(line.trim_end()), expected))
            .all(|(a, b)| a == b);
        assert!(ok);
    }
}
