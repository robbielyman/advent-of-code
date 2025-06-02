use std::collections::HashMap;
use std::env;

pub fn main() {
    let args: Vec<String> = env::args().collect();
    let output = process(&args[1]).unwrap();
    println!("{}", output);
}

fn process(input: &str) -> Option<u32> {
    let n: u32 = input.parse().ok()?;
    let it = Spiraler::new();
    let mut map = HashMap::<Position, u32>::new();
    map.insert(Position { x: 0, y: 0 }, 1);
    for position in it {
        let val = position
            .neighbors()
            .iter()
            .filter_map(|neighbor| map.get(neighbor))
            .sum();
        map.insert(position, val);
        if val > n {
            return Some(val);
        }
    }
    None
}

struct Spiraler {
    x: Bounds,
    y: Bounds,
    current: Position,
    direction: Direction,
}

impl Spiraler {
    fn new() -> Self {
        let x = Bounds::new();
        let y = Bounds::new();
        Self {
            x,
            y,
            current: Position { x: 0, y: 0 },
            direction: Direction::Right,
        }
    }
}

impl Iterator for Spiraler {
    type Item = Position;

    fn next(&mut self) -> Option<Self::Item> {
        let delta = self.direction.delta();
        self.current.x += delta.x;
        self.current.y += delta.y;
        if self.x.update(self.current.x) || self.y.update(self.current.y) {
            self.direction.update();
        }
        Some(self.current)
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
struct Position {
    x: i32,
    y: i32,
}

impl Position {
    fn neighbors(self) -> [Self; 8] {
        let deltas = [
            Position { x: -1, y: -1 },
            Position { x: 0, y: -1 },
            Position { x: 1, y: -1 },
            Position { x: 1, y: 0 },
            Position { x: 1, y: 1 },
            Position { x: 0, y: 1 },
            Position { x: -1, y: 1 },
            Position { x: -1, y: 0 },
        ];
        let mut ret = [self; 8];
        for (delta, val) in std::iter::zip(deltas.iter(), ret.iter_mut()) {
            val.x += delta.x;
            val.y += delta.y;
        }
        ret
    }
}

struct Bounds {
    min: i32,
    max: i32,
}

impl Bounds {
    fn new() -> Self {
        Self { min: 0, max: 0 }
    }

    fn update(&mut self, val: i32) -> bool {
        if val > self.max || val < self.min {
            self.max = std::cmp::max(val, self.max);
            self.min = std::cmp::min(val, self.min);
            return true;
        }
        false
    }
}

enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    fn update(&mut self) {
        use Direction::*;
        *self = match *self {
            Up => Left,
            Left => Down,
            Down => Right,
            Right => Up,
        }
    }

    fn delta(&self) -> Position {
        use Direction::*;
        let (x, y) = match *self {
            Up => (0, 1),
            Left => (-1, 0),
            Down => (0, -1),
            Right => (1, 0),
        };
        Position { x, y }
    }
}
