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
}

impl Map {
    fn from(input: &str) -> Self {
        let data = input.lines()
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
            .collect();
        Self { data }
    }

    #[cfg(not(test))]
    fn fold(&self, i: usize, j: usize, heading: usize) -> (usize, usize, usize) {
        let mut try_this = match heading {
                0 => (i, j + 1, heading),
                1 => (i + 1, j, heading),
                2 => (i, j - 1, heading),
                3 => (i - 1, j, heading),
                _ => unreachable!(),
            };
            if self.data.get(&(try_this.0, try_this.1)).is_none() {
                try_this = match try_this {
                    (0, j, 3) if 51 <= j && j <= 100 => (j + 100, 1, 0),
                    (0, j, 3) if 101 <= j && j <= 150 => (200, j - 100, 3),
                    (100, j, 3) if 1 <= j && j <= 50 => (j + 50, 51, 0),
                    (i, 151, 0) if 1 <= i && i <= 50 => (151 - i, 100, 2),
                    (i, 101, 0) if 51 <= i && i <= 100 => (50, i + 50, 3),
                    (i, 101, 0) if 101 <= i && i <= 150 => (51 - (i - 100), 150, 2),
                    (i, 51, 0) if 151 <= i && i <= 200 => (150, i - 100, 3),
                    (201, j, 1) if 1 <= j && j <= 50 => (1, j + 100, 1),
                    (151, j, 1) if 51 <= j && j <= 100 => (j + 100, 50, 2),
                    (51, j, 1) if 101 <= j && j <= 150 => (j - 50, 100, 2),
                    (i, 50, 2) if 1 <= i && i <= 50 => (151 - i, 1, 0),
                    (i, 50, 2) if 51 <= i && i <= 100 => (101, i - 50, 1),
                    (i, 0, 2) if 101 <= i && i <= 150 => (51 - (i - 100), 51, 0),
                    (i, 0, 2) if 151 <= i && i <= 200 => (1, i - 100, 1),
                    _ => unreachable!(),
                };
            }
            match self.data.get(&(try_this.0, try_this.1)) {
                None => panic!("{}, {}, {}", try_this.0, try_this.1, try_this.2),
                Some(true) => (i, j, heading),
                Some(false) => try_this,
            }
    }

    #[cfg(test)]
    fn fold(&self, i: usize, j: usize, heading: usize) -> (usize, usize, usize) {
        let mut try_this = match heading {
                0 => (i, j + 1, heading),
                1 => (i + 1, j, heading),
                2 => (i, j - 1, heading),
                3 => (i - 1, j, heading),
                _ => unreachable!(),
            };
            if self.data.get(&(try_this.0, try_this.1)).is_none() {
                try_this = match try_this {
                    (4, j, 3) if 1 <= j && j <= 4 => (12, j + 8, 3),
                    (4, j, 3) if 5 <= j && j <= 8 => (j - 4, 9, 0),
                    (0, j, 3) if 9 <= j && j <= 12 => (5, 5 - (j - 8), 1),
                    (8, j, 3) if 13 <= j && j <= 16 => (9 - (j - 12), 12, 2),
                    (i, 13, 0) if 1 <= i && i <= 4 => (13 - i, 16, 2),
                    (i, 13, 0) if 5 <= i && i <= 8 => (9, 17 - (i - 4), 1),
                    (i, 17, 0) if 9 <= i && i <= 12 => (5 - (i - 8), 12, 2),
                    (9, j, 1) if 1 <= j && j <= 4 => (1, j + 8, 1),
                    (9, j, 1) if 5 <= j && j <= 8 => (13 - (j - 4), 9, 0),
                    (13, j, 1) if 9 <= j && j <= 12 => (8, 5 - (j - 8), 3),
                    (13, j, 1) if 13 <= j && j <= 16 => (9 - (j - 12), 1, 0),
                    (i, 8, 2) if 1 <= i && i <= 4 => (5, i + 4, 1),
                    (i, 0, 2) if 5 <= i && i <= 8 => (12, 17 - (i - 4), 3),
                    (i, 8, 2) if 9 <= i && i <= 12 => (8, 9 - (i - 8), 3),
                    _ => unreachable!(),
                };
            }
            match self.data.get(&(try_this.0, try_this.1)) {
                None => panic!("{}, {}, {}", try_this.0, try_this.1, try_this.2),
                Some(true) => (i, j, heading),
                Some(false) => try_this,
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
                res = self.fold(res.0, res.1, res.2);
                count -= 1;
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
        assert_eq!((5,7,3), output);
    }
}
