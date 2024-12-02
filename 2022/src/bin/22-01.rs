use std::{collections::HashMap, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("22.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let (map, input) = input.split_once("\n\n").unwrap();
    let map = Map::from(map);
    let res = map.walk(input);
    println!("{}", res.0 * 1000 + 4 * res.1 + res.2);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

struct Map {
    data: HashMap<(usize, usize), bool>,
    wid: usize,
    hei: usize,
}

impl Map {
    fn from(input: &str) -> Self {
        let mut wid = 0;
        let mut hei = 0;
        Self {
            data: input.lines()
                .enumerate()
                .flat_map(|(i, line)| {
                    line.chars()
                        .enumerate()
                        .filter_map(move |(j, ch)| {
                            match ch {
                                '.' => Some(((i + 1, j + 1), false)),
                                '#' => Some(((i + 1, j + 1), true)),
                                _ => None
                            }
                        })
                })
                .inspect(|((i, j), _)| {
                    wid = wid.max(*j);
                    hei = hei.max(*i);
                })
                .collect(),
            wid,
            hei
        }
    }

    fn walk(&self, string: &str) -> (usize, usize, usize) {
        let input = string.trim_end_matches('\n').as_bytes();
        let mut idx = 0;
        let mut res = (1, 1, 0);
        while self.data.get(&(res.0, res.1)).is_none() {
            res.1 += 1;
        }
        while idx < input.len() {
            let mut count: usize = input[idx..].iter()
                .copied()
                .take_while(|&byte| byte != b'L' && byte != b'R')
                .map(|byte| {
                    idx += 1;
                    byte as char
                })
                .collect::<String>()
                .parse()
                .unwrap();
            while count > 0 {
                let mut next = (res.0, res.1);
                match res.2 {
                    0 => next.1 += 1,
                    1 => next.0 += 1,
                    2 => next.1 -= 1,
                    3 => next.0 -= 1,
                    _ => unreachable!(),
                };
                while self.data.get(&next).is_none() {
                    match res.2 {
                        0 => if next.1 > self.wid { next.1 = 1; } else { next.1 += 1; },
                        1 => if next.0 > self.hei { next.0 = 1; } else { next.0 += 1; },
                        2 => if next.1 == 0 { next.1 = self.wid; } else { next.1 -= 1; },
                        3 => if next.0 == 0 { next.0 = self.hei; } else { next.0 -= 1; },
                        _ => unreachable!(),
                    };
                }
                match self.data.get(&next) {
                    Some(true) => {
                        count = 0;
                    },
                    Some(false) => {
                        count -= 1;
                        res.0 = next.0;
                        res.1 = next.1;
                    },
                    None => unreachable!(),
                }
            }
            if idx < input.len() {
                res.2 = match input[idx] {
                    b'L' => (res.2 + 3) % 4,
                    b'R' => (res.2 + 1) % 4,
                    _ => unreachable!(),
                };
                idx += 1;
            }
        }
        res
    }
}

#[cfg(test)]
mod tests {
    use crate::Map;

    const INPUT: &str = "        ...#
        .#..
        #...
        ....
...#.......#
........#...
..#....#....
..........#.
        ...#....
        .....#..
        .#......
        ......#.

10R5L5R10L4R5L5
";

    #[test]
    fn walk() {
        let (map, input) = INPUT.split_once("\n\n").unwrap();
        let map = Map::from(map);
        let output = map.walk(input);
        assert_eq!((6,8,0), output);
    }
}
