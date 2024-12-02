use itertools::Itertools;
use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("03.txt");
    let mut file = match File::open(&path) {
        Err(why) => panic!("couldn't open {}: {}", path.display(), why),
        Ok(file) => file,
    };
    let mut input = String::new();
    match file.read_to_string(&mut input) {
        Err(why) => panic!("unable to read {}: {}", path.display(), why),
        Ok(_) => {}
    };
    println!("{}", prioritize(input));
}

fn priority(c: char) -> u32 {
    match c {
        'a'..='z' =>             c as u32 - ('a' as u32 - 1),
        'A'..='Z' => c as u32 - ('A' as u32 - 1) + 26,
        _ => panic!("upper or lowercase letter expected!"),
    }
}

fn prioritize(string: String) -> u32 {
    let mut p: u32 = 0;
    for rucksack in string.split_terminator('\n') {
        let (first, second) = rucksack.split_at(rucksack.len() / 2);
        let pr: u32 = first.chars()
            .unique()
            .filter_map(|c| match second.find(c){
            Some(_) => Some(c),
            None => None,
            })
            .map(priority)
            .sum();
        p += pr
    }
    p
}

#[cfg(test)]
mod tests {
    use crate::prioritize;

    const INPUT: &str = "vJrwpWtwJgWrhcsFMMfFFhFp
jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
PmmdzqPrVvPwwTWBwg
wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
ttgJtRGJQctTZtZT
CrZsJsPPZsGzwwsLwLmpwMDw
";
    #[test]
    fn rucksacks() {
        let priority = prioritize(INPUT.to_string());
        assert_eq!(priority, 157);
    }
}
