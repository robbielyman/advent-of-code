use std::{fs::File, io::Read, ops::Sub, path::Path};

use itertools::Itertools;

#[derive(Clone, Copy, Hash, Eq)]
struct Position {
    x: i32,
    y: i32,
}

impl PartialEq for Position {
    fn eq(&self, other: &Self) -> bool {
        self.x == other.x && self.y == other.y
    }
}

impl Sub<Self> for Position {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self::Output {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
        }
    }
}

enum Direction {
    Left,
    Right,
    Up,
    Down,
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

struct HeadIterator<'a> {
    p: &'a mut Position,
    d: Direction,
    num: usize,
}

impl<'a> HeadIterator<'a> {
    fn new(p: &'a mut Position, d: Direction, num: usize) -> Self {
        Self { p, d, num }
    }
}

impl<'a> Iterator for HeadIterator<'a> {
    type Item = Position;

    fn next(&mut self) -> Option<Self::Item> {
        if self.num == 0 {
            return None;
        }
        self.num -= 1;
        match self.d {
            Direction::Left => self.p.x -= 1,
            Direction::Right => self.p.x += 1,
            Direction::Up => self.p.y += 1,
            Direction::Down => self.p.y -= 1,
        }
        Some(self.p.clone())
    }
}

fn follow<'a, I: Iterator<Item = Position>>(head: &'a mut I, initial: Position) -> FollowIterator<'a, I> {
    FollowIterator { head, state: initial }
}

struct FollowIterator<'a, I: Iterator<Item = Position>> {
    head: &'a mut I,
    state: Position,
}

impl<'a, I: Iterator<Item = Position>> FollowIterator<'a, I> {
    fn follow(&'a mut self, initial: Position) -> FollowIterator<'a, Self> {
        FollowIterator {
            head: self,
            state: initial,
        }
    }
}

impl<'a, I: Iterator<Item = Position>> Iterator for FollowIterator<'a, I> {
    type Item = Position;

    fn next(&mut self) -> Option<Self::Item> {
        let new_head = self.head.next()?;
        let old_tail = self.state;
        match new_head - old_tail {
            Position { x, y } => match x.abs() + y.abs() {
                0..=1 => {} // still touching
                2 => {
                    if x == 0 {
                        // same column
                        self.state.y += y / 2;
                    } else if y == 0 {
                        // same row
                        self.state.x += x / 2;
                    } // else diagonal
                }
                _ => {
                    // always move diagonal
                    if x > 0 {
                        self.state.x += 1;
                    } else if x < 0 {
                        self.state.x -= 1;
                    }
                    if y > 0 {
                        self.state.y += 1;
                    } else if y < 0 {
                        self.state.y -= 1;
                    }
                }
            },
        }
        Some(self.state)
    }
}

fn count_unique(input: &str) -> usize {
    let mut starting = Position { x: 0, y: 0 };
    let initial = Position { x: 0, y: 0 };
    follow(&mut input
        .lines()
        .map(|line| {
            let mut tokens = line.split_whitespace();
            let d = Direction::from(tokens.next().unwrap().chars().next().unwrap()).unwrap();
            let num: usize = tokens.next().unwrap().parse().unwrap();
            HeadIterator::new(&mut starting, d, num)
                .collect_vec()
        })
        .flatten(), initial) // 1
        .follow(initial) // 2
        .follow(initial) // 3
        .follow(initial) // 4
        .follow(initial) // 5
        .follow(initial) // 6
        .follow(initial) // 7,
        .follow(initial) // 8,
        .follow(initial) // 9
        .unique()
        .count()
}

fn main() {
    let path = Path::new("09.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let count = count_unique(&input);
    println!("{}", count);
}

#[cfg(test)]
mod tests {
    use crate::count_unique;

    const INPUT: &str = "R 5
U 8
L 8
D 3
R 17
D 10
L 25
U 20
";

    #[test]
    fn motion() {
        assert_eq!(count_unique(INPUT), 36);
    }
}
