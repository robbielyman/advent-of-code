use std::{fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("02.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = process(&input);
    println!("{}", output);
    println!("time elapsed: {}us", now.elapsed().as_micros());
}

fn process(input: &str) -> i32 {
    let (horiz, vert) = input.lines().fold((0, 0), |(horiz, vert), line| {
        let (direction, remainder) = line.split_once(' ').unwrap();
        let change: i32 = remainder.parse().unwrap();
        match direction {
            "forward" => (horiz + change, vert),
            "up" => (horiz, vert - change),
            "down" => (horiz, vert + change),
            _ => panic!("bad input!"),
        }
    });
    horiz * vert
}

#[cfg(test)]
mod tests {
    use crate::process;

    const INPUT: &str = "forward 5
down 5
forward 8
up 3
down 8
forward 2
";
    
    #[test]
    fn it_works() {
        let output = process(INPUT);
        assert_eq!(150, output);
    }
}
