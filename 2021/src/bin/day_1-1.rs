use std::{fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("01.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = process(&input);
    println!("{}", output);
    println!("time elapsed: {}us", now.elapsed().as_micros());
}

fn process(input: &str) -> usize {
    let mut last = 0;
    input
        .lines()
        .map(|line| line.parse::<i32>().expect("number expected!"))
        .filter(|&x| {
            let l = last;
            last = x;
            l > 0 && x > l
        })
        .count()
}

#[cfg(test)]
mod tests {
    use crate::process;

    const INPUT: &str = "199
200
208
210
200
207
240
269
260
263
";

    #[test]
    fn it_works() {
        let output = process(INPUT);
        assert_eq!(7, output);
    }
}
