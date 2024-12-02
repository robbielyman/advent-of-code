use std::{fs::File, io::Read, path::Path};

fn main() {
    let path = Path::new("10.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let signal_strength = walk(&input);
    println!("{}", signal_strength);
}

fn walk(input: &str) -> i32 {
    let mut num = 0;
    let mut state = 1;
    let mut init = 20;
    let mut last = 1;
    input
        .lines()
        .map(|line| {
            let mut splitter = line.split_whitespace();
            match splitter.next() {
                Some("addx") => (2, splitter.next().unwrap().parse::<i32>().unwrap()),
                Some("noop") => (1, 0),
                Some(_) => panic!("bad parse!"),
                None => panic!("bad parse!"),
            }
        })
        .map(|(i, j)| {
            num += i;
            state += j;
            (num, state)
        })
        .filter_map(|(n, s)| {
            if n < init {
                last = s;
                return None;
            }
            let l = last;
            let i = init;
            last = s;
            init += 40;
            Some((i, l))
        })
        .take_while(|(n, _)| {
            n <= &220
        })
        .map(|(i, j)| i * j)
        .sum()
}

#[cfg(test)]
mod tests {
    use crate::walk;

    const INPUT: &str = "addx 15
addx -11
addx 6
addx -3
addx 5
addx -1
addx -8
addx 13
addx 4
noop
addx -1
addx 5
addx -1
addx 5
addx -1
addx 5
addx -1
addx 5
addx -1
addx -35
addx 1
addx 24
addx -19
addx 1
addx 16
addx -11
noop
noop
addx 21
addx -15
noop
noop
addx -3
addx 9
addx 1
addx -3
addx 8
addx 1
addx 5
noop
noop
noop
noop
noop
addx -36
noop
addx 1
addx 7
noop
noop
noop
addx 2
addx 6
noop
noop
noop
noop
noop
addx 1
noop
noop
addx 7
addx 1
noop
addx -13
addx 13
addx 7
noop
addx 1
addx -33
noop
noop
noop
addx 2
noop
noop
noop
addx 8
noop
addx -1
addx 2
addx 1
noop
addx 17
addx -9
addx 1
addx 1
addx -3
addx 11
noop
noop
addx 1
noop
addx 1
noop
noop
addx -13
addx -19
addx 1
addx 3
addx 26
addx -30
addx 12
addx -1
addx 3
addx 1
noop
noop
noop
addx -9
addx 18
addx 1
addx 2
noop
noop
addx 9
noop
noop
noop
addx -1
addx 2
addx -37
addx 1
addx 3
noop
addx 15
addx -21
addx 22
addx -6
addx 1
noop
addx 2
addx 1
noop
addx -10
noop
noop
addx 20
addx 1
addx 2
addx 2
addx -6
addx -11
noop
noop
noop
";

    #[test]
    fn test_walk() {
        let output = walk(INPUT);
        assert_eq!(output, 13140);
    }
}
