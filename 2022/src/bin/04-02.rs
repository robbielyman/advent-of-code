use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("04.txt");
    let mut file = match File::open(&path) {
        Err(why) => panic!("couldn't open {}: {}", path.display(), why),
        Ok(file) => file,
    };
    let mut input = String::new();
    match file.read_to_string(&mut input) {
        Err(why) => panic!("unable to read {}: {}", path.display(), why),
        Ok(_) => {}
    };
    println!("{}", count_overlap(input));
}

struct Range {
    first: u32,
    last: u32,
}

impl Range {
    fn overlap(r: &Self, s: &Self) -> bool {
        (r.first <= s.first && s.first <= r.last) || (s.first <= r.first && r.first <= s.last)
    }

    fn from_str(string: &str) -> Option<Range> {
        let (first, last) = string.split_once('-')?;
        Some(Range {
            first: first.parse().ok()?,
            last: last.parse().ok()?,
        })
    }
}

fn count_overlap(string: String) -> usize {
    string
        .split_terminator('\n')
        .filter_map(|pair| {
            let (first, second) = pair.split_once(',')?;
            let first_range = Range::from_str(first)?;
            let second_range = Range::from_str(second)?;
            Some(Range::overlap(&first_range, &second_range))
        })
        .filter(|b| *b)
        .count()
}

#[cfg(test)]
mod tests {
    use crate::{count_overlap, Range};

    const INPUT: &str = "2-4,6-8
2-3,4-5
5-7,7-9
2-8,3-7
6-6,4-6
2-6,4-8
";

    #[test]
    fn test_overlap() {
        let r = Range { first: 2, last: 3 };
        let s = Range { first: 4, last: 5 };
        assert!(!Range::overlap(&r, &s));
    }

    #[test]
    fn test_count() {
        let number = count_overlap(String::from(INPUT));
        assert_eq!(number, 4);
    }
}
