use std::{fs::File, io::Read, path::Path};

use itertools::Itertools;

struct Rope {
    head: Position,
    tail: Position,
}

impl Rope {
    fn new() -> Self {
        Rope { head: Position { x: 0, y: 0 }, tail: Position { x: 0, y: 0} }
    }
}

#[derive(Clone, Copy, Hash, Eq)]
struct Position {
    x: i32, y: i32
}

impl PartialEq for Position {
    fn eq(&self, other: &Self) -> bool {
        self.x == other.x && self.y == other.y
    }
}

enum Direction {
    Left, Right, Up, Down
}

impl Direction {
    fn from(ch: char) -> Option<Self> {
        match ch {
            'R' => Some(Direction::Right),
            'L' => Some(Direction::Left),
            'U' => Some(Direction::Up),
            'D' => Some(Direction::Down),
            _ => None,
        }
    }
}

struct RopeIterator<'a> {
    r: &'a mut Rope,
    d: Direction,
    num: usize,
}

impl<'a> RopeIterator<'a> {
    fn new(r: &'a mut Rope, d: Direction, num: usize) -> Self {
        RopeIterator { r, d, num }
    }
}

impl<'a> Iterator for RopeIterator<'a> {
    type Item = Position;

    fn next(&mut self) -> Option<Self::Item> {
        if self.num == 0 { return None; }
        self.num -= 1;
        match self.d {
            Direction::Left => {
                self.r.head.x -= 1;
                if (self.r.head.x - self.r.tail.x).abs() > 1 {
                    self.r.tail.x -= 1;
                    self.r.tail.y = self.r.head.y;
                }
                Some(self.r.tail.clone())
            },
            Direction::Right => {
                self.r.head.x += 1;
                if (self.r.head.x - self.r.tail.x).abs() > 1 {
                    self.r.tail.x += 1;
                    self.r.tail.y = self.r.head.y;
                }
                Some(self.r.tail.clone())
            },
            Direction::Up => {
                self.r.head.y += 1;
                if (self.r.head.y - self.r.tail.y).abs() > 1 {
                    self.r.tail.y += 1;
                    self.r.tail.x = self.r.head.x;
                }
                Some(self.r.tail.clone())
            },
            Direction::Down => {
                self.r.head.y -= 1;
                if (self.r.head.y - self.r.tail.y).abs() > 1 {
                    self.r.tail.y -= 1;
                    self.r.tail.x = self.r.head.x;
                }
                Some(self.r.tail.clone())
            }
        }
    }
}

fn count_unique(rope: &mut Rope, input: &str) -> usize {
    input.lines()
            .map(|line| {
            let mut tokens = line.split_whitespace();
            let d = Direction::from(tokens.next()
                                    .unwrap()
                                    .chars().next().unwrap())
                .unwrap();
                let num: usize = tokens.next().unwrap().parse().unwrap();
                RopeIterator::new(rope, d, num)
                    .collect_vec()
            })
            .flatten()
            .unique()
            .count()
}

fn main() {
    let path = Path::new("09.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let mut rope = Rope::new();
    let count = count_unique(&mut rope, &input);
    println!("{}", count);
}

#[cfg(test)]
mod tests {
    use crate::{count_unique, Rope};

    const INPUT: &str = "R 4
U 4
L 3
D 1
R 4
D 1
L 5
R 2
";

    #[test]
    fn motion() {
        let mut rope = Rope::new();
        assert_eq!(count_unique(&mut rope, INPUT), 13);
    }
}
