use std::{fs::File, io::Read, path::Path, time::Instant};

pub fn main() {
    let path = Path::new("01.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = process(&input);
    println!("{}", output);
    println!("elapsed time: {}us", now.elapsed().as_micros())
}

fn process(input: &str) -> i32 {
    let (left, right): (Vec<_>, Vec<_>) = input.lines()
        .map(|line| {
            let (left, right) = line.split_once("   ").expect("bad input");
            (left.parse::<i32>().unwrap(), right.parse::<i32>().unwrap())
        })
        .unzip();
    left.iter()
        .map(|item| {
            (item, right.iter().filter(|&other| item == other).count())
        })
        .fold(0, |total, (&item, count)| {
            let count = count as i32;
            total + (item * count)
        })
}

#[cfg(test)]
mod tests {
    use crate::process;

    const TEST_INPUT: &str = "3   4
4   3
2   5
1   3
3   9
3   3
";

    #[test]
    fn day_one_pt_two() {
        let output = process(TEST_INPUT);
        assert_eq!(31, output)
    }
}
