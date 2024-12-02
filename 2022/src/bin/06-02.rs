use std::collections::HashSet;
use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("06.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    println!("{}", find_different(&input).expect("bad input"));
}

fn find_different(input: &str) -> Option<usize> {
    let mut rolling_list = ['\0'; 14];
    for (i, ch) in input.chars().enumerate() {
        let idx = i % 14;
        rolling_list[idx] = ch;
        if i >= 13 {
            let hash_set: HashSet<char> = rolling_list.iter()
                .copied()
                .collect();
            if hash_set.len() == 14 {
               return Some(i + 1);
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use crate::find_different;

    const INPUT: &str = "mjqjpqmgbljsphdztnvjfqwrcgsmlb";

    #[test]
    fn test_case_gives_nineteen() {
        let nineteen = find_different(INPUT);
        assert_eq!(Some(19), nineteen);
    }
}
