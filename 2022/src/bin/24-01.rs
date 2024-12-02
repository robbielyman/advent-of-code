use std::{collections::HashSet, fs::File, io::Read, ops::{Add, Sub}, path::Path, time::Instant};

fn main() {
    let path = Path::new("24.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = solve(&input);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

#[derive(Copy, Clone)]
enum Blocker {
    Wall(Location),
    Left(Location),
    Right(Location),
    Up(Location),
    Down(Location),
}

#[derive(Hash, PartialEq, Eq, Copy, Clone)]
struct Location {
    x: u32,
    y: u32,
}

impl Sub for Location {
    type Output=Option<Self>;

    fn sub(self, rhs: Self) -> Self::Output {
        if rhs.x > self.x { None }
        else if rhs.y > self.y { None }
        else { Some(Self { x: self.x - rhs.x, y: self.y - rhs.y }) }
    }
}

impl Add for Location {
    type Output=Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self { x: self.x + rhs.x, y: self.y + rhs.y }
    }
}

fn parse(input: &str) -> (Vec<Blocker>, u32, u32) {
    let wid = input.split_once('\n').unwrap().0.len();
    let hei = input.lines().count();
    (input.lines()
        .enumerate()
        .flat_map(|(y, line)| {
            line.chars()
                .enumerate()
                .filter_map(move |(x, ch)| {
                    let x: u32 = x.try_into().unwrap();
                    let y: u32 = y.try_into().unwrap();
                    match ch {
                        '#' => Some(Blocker::Wall(Location { x, y })),
                        '<' => Some(Blocker::Left(Location { x, y })),
                        '>' => Some(Blocker::Right(Location { x, y })),
                        '^' => Some(Blocker::Up(Location { x, y })),
                        'v' => Some(Blocker::Down(Location { x, y })),
                        _ => None,
                }})
        })
        .collect(), wid.try_into().unwrap(), hei.try_into().unwrap())
}

fn tick(blockers: &mut Vec<Blocker>, width: u32, height: u32) -> HashSet<Location> {
    for b in blockers.iter_mut() {
        match b {
            Blocker::Wall(_) => {},
            Blocker::Left(location) => {
                location.x -= 1;
                if location.x == 0 { location.x = width - 2; }
            },
            Blocker::Right(location) => {
                location.x += 1;
                if location.x == width - 1 { location.x = 1; }
            },
            Blocker::Up(location) => {
                location.y -= 1;
                if location.y == 0 { location.y = height - 2; }
            },
            Blocker::Down(location) => {
                location.y += 1;
                if location.y == height - 1 { location.y = 1; }
            }
        }
    }
    blockers.iter()
        .copied()
        .map(|b| {
            match b {
                Blocker::Wall(l) => l,
                Blocker::Left(l) => l,
                Blocker::Right(l) => l,
                Blocker::Up(l) => l,
                Blocker::Down(l) => l,
            }
        })
        .collect()
}

fn solve(input: &str) -> usize {
    let (mut blockers, width, height) = parse(input);
    let mut states = vec![Location { x: 1, y: 0 }];
    let mut round = 0;
    while !states.iter().any(|state| *state == Location { x: width - 2, y: height - 1 }) {
        let mut set = tick(&mut blockers, width, height);
        states = states.into_iter()
            .flat_map(|state| {
                const OPERANDS: &[Location] = &[Location { x: 1, y: 0 }, Location { x: 0, y: 1 }];
                const POS_OPERANDS: &[Location] = &[Location { x: 1, y: 0 }, Location { x: 0, y: 1 }, Location { x: 0, y: 0 }];
                OPERANDS.iter()
                    .filter_map(move |operand| state - *operand)
                    .chain(POS_OPERANDS.iter()
                        .map(move |operand| state + *operand))
            })
            .filter(|state| {
                let ret = !set.contains(state);
                set.insert(*state);
                ret
            })
            .collect();
        round += 1;
    }
    round
}

#[cfg(test)]
mod tests {
    use crate::solve;

    const INPUT: &str = "#.######
#>>.<^<#
#.<..<<#
#>v.><>#
#<^v^^>#
######.#
";

    #[test]
    fn test_it() {
        let stage = solve(INPUT);
        assert_eq!(stage, 18);
    }
}
