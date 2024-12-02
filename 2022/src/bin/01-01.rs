use std::cmp::max;
use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("01.txt");
    let display = path.display();
    let mut file = match File::open(&path) {
        Err(why) => panic!("couldn't open {}: {}", display, why),
        Ok(file) => file,
    };
    let mut input = String::new();
    match file.read_to_string(&mut input) {
        Err(why) => panic!("unable to read {}: {}", display, why),
        Ok(length) => _ = length,
    };
    let maximum = find_maximum(input);
    println!("{}", maximum);
}

fn find_maximum(string: String) -> usize {
    let mut maximum: usize = 0;
    for elves in string.split("\n\n") {
        let mut elf_total: usize = 0;
        for caloric_amount in elves.split_terminator("\n") {
            let calories: usize = match caloric_amount.parse() {
                Err(why) => panic!("error parsing! {}", why),
                Ok(calories) => calories,
            };
            elf_total += calories;
        }
        maximum = max(maximum, elf_total);
    }
    maximum
}

#[cfg(test)]
mod tests {
    use crate::find_maximum;

    const INPUT: &str = "1000
2000
3000

4000

5000
6000

7000
8000
9000

10000
";
    #[test]
    fn it_passes() {
        let maximum = find_maximum(INPUT.to_string());
        assert_eq!(maximum, 24000);
    }
}
