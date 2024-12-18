use std::{fs::File, io::Read, path::Path};

fn main() {
    let path = Path::new("10.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let output = draw(&input);
    print!("{}", output);
}

fn draw(input: &str) -> String {
    let mut num = 0;
    let mut state = 1;
    let mut pixel = 0;
    let mut output = String::new();
    for (len, change) in input
        .lines()
        .map(|line| {
            let mut splitter = line.split_whitespace();
            match splitter.next() {
                Some("addx") => (2, splitter.next().unwrap().parse::<i32>().unwrap()),
                Some("noop") => (1, 0),
                Some(_) => panic!("bad parse!"),
                None => panic!("bad parse!"),
            }
        }) {
            num += len;
            while pixel < num {
                output.push(match ((pixel % 40 - state) as i32).abs() {
                    0..=1 => '#',
                    _ => '.'
                });
                pixel += 1;
                if pixel % 40 == 0 {
                    output.push('\n');
                }
            }
            state += change;
        }
        output
}

#[cfg(test)]
mod tests {
    use crate::draw;

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

    const OUTPUT: &str = "##..##..##..##..##..##..##..##..##..##..
###...###...###...###...###...###...###.
####....####....####....####....####....
#####.....#####.....#####.....#####.....
######......######......######......####
#######.......#######.......#######.....
";
    
    #[test]
    fn test_draw() {
        let output = draw(INPUT);
        assert_eq!(output, OUTPUT.to_string());
    }
}
