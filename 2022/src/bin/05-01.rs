use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("05.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let (crates_input, operations) = input.split_once("\n\n").expect("split input");
    let mut crates = Crates::from(crates_input).expect("parsing crates");
    operations.lines()
        .for_each(|operation| {
            let args: Vec<usize> = operation
                .split_whitespace()
                .filter_map(|token| {
                    let num: usize = token.parse().ok()?;
                    Some(num)
                })
                .collect();
            assert_eq!(args.len(), 3);
            crates.operate(args[0], args[1] - 1, args[2] - 1);
        });
    let res: String = crates.data.into_iter()
            .filter_map(|vec| {
                        let ch = vec.last()?;
                        Some(ch.clone())
            })
        .collect();
    println!("{}", res);
}

struct Crates {
    data: Vec<Vec<char>>,
}

impl Crates {
    fn from(string: &str) -> Option<Crates> {
        let mut iter = string.lines().rev();
        let num: usize = iter.next()?.split_whitespace().rev().next()?.parse().ok()?;
        let mut data: Vec<Vec<char>> = Vec::new();
        for _ in 0..num {
            data.push(Vec::new());
        }
        let mut crates = Crates { data };
        for line in iter {
            line.chars().skip(1).step_by(4).fold(0 as usize, |i, ch| {
                if ch != ' ' {
                    crates.data[i].push(ch);
                }
                i + 1
            });
        }
        Some(crates)
    }

    fn operate(&mut self, num: usize, from: usize, to: usize) {
        for _ in 0..num {
            let ch = self.data[from].pop().expect("pop");
            self.data[to].push(ch);
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::Crates;

    const INPUT: &str = "    [D]    
[N] [C]    
[Z] [M] [P]
 1   2   3 

move 1 from 2 to 1
move 3 from 1 to 3
move 2 from 2 to 1
move 1 from 1 to 2
";
    #[test]
    fn test_crates() {
        let (crates_input, operations) = INPUT.split_once("\n\n").unwrap();
        let mut crates = Crates::from(crates_input).unwrap();
        assert_eq!(crates.data.len(), 3);
        assert_eq!(crates.data[0].len(), 2);
        assert_eq!(crates.data[1].len(), 3);
        assert_eq!(crates.data[2].len(), 1);
        operations.split_terminator('\n').for_each(|operation| {
            let args: Vec<usize> = operation
                .split_whitespace()
                .filter_map(|token| {
                    let num: usize = token.parse().ok()?;
                    Some(num)
                })
                .collect();
            assert_eq!(args.len(), 3);
            crates.operate(args[0], args[1] - 1, args[2] - 1);
        });
        let res: String = crates.data.into_iter()
            .filter_map(|vec| {
                        let ch = vec.last()?;
                        Some(ch.clone())
            })
            .collect();
        assert_eq!(res, "CMZ");
    }
}
