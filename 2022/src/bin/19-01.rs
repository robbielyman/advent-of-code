use std::{cmp::Ordering, fs::File, io::Read, ops::{Add, Mul, Sub}, path::Path, time::Instant};

fn main() {
    let path = Path::new("19.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = best_paths(&input);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

fn parse(input: &str) -> [(Resource, Resource); 5] {
        let vec: Vec<_> = input.split_whitespace()
            .filter_map(|token| {
                let item: u16 = token.parse().ok()?;
                Some(item)
            })
            .collect();
    [
        (Resource { ore: 0, clay: 0, obsidian: 0, geode: 0 },
        Resource { ore: 0, clay: 0, obsidian: 0, geode: 0 }),
        (Resource { ore: vec[0], clay: 0, obsidian: 0, geode: 0 },
        Resource { ore: 1, clay: 0, obsidian: 0, geode: 0 }),
        (Resource { ore: vec[1], clay: 0, obsidian: 0, geode: 0 },
        Resource { ore: 0, clay: 1, obsidian: 0, geode: 0 }),
        (Resource { ore: vec[2], clay: vec[3], obsidian: 0, geode: 0 },
        Resource { ore: 0, clay: 0, obsidian: 1, geode: 0 }),
        (Resource { ore: vec[4], clay: 0, obsidian: vec[5], geode: 0 },
        Resource { ore: 0, clay: 0, obsidian: 0, geode: 1 })
    ]
}


#[derive(Copy, Clone, PartialEq, Eq, Debug)]
struct Resource {
    ore: u16,
    clay: u16,
    obsidian: u16,
    geode: u16,
}

impl PartialOrd for Resource {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        let ords = [self.ore.cmp(&other.ore), self.clay.cmp(&other.clay), self.obsidian.cmp(&other.obsidian), self.geode.cmp(&other.geode)];
        if ords.iter().any(|&ordering| ordering == Ordering::Less) && ords.iter().any(|&ordering| ordering == Ordering::Greater) {
            None
        } else if ords.iter().any(|&ordering| ordering == Ordering::Less) {
            Some(Ordering::Less)
        } else if ords.iter().any(|&ordering| ordering == Ordering::Greater) {
            Some(Ordering::Greater)
        } else {
            Some(Ordering::Equal)
        }
    }
}

impl Sub for Resource {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self::Output {
            ore: self.ore - rhs.ore,
            clay: self.clay - rhs.clay,
            obsidian: self.obsidian - rhs.obsidian,
            geode: self.geode - rhs.geode,
        }
    }
}

impl Add for Resource {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self::Output {
            ore: self.ore + rhs.ore,
            clay: self.clay + rhs.clay,
            obsidian: self.obsidian + rhs.obsidian,
            geode: self.geode + rhs.geode,
        }
    }
}

impl Mul<u16> for Resource {
    type Output = Self;

    fn mul(self, rhs: u16) -> Self::Output {
        Self::Output {
            ore: self.ore * rhs,
            clay: self.clay * rhs,
            obsidian: self.obsidian * rhs,
            geode: self.geode * rhs,
        }
    }
}

fn best_paths(input: &str) -> u16 {
    input.lines()
        .map(parse)
        .map(|blueprint| {
            let mut states = vec![(
                Resource { ore: 0, clay: 0, obsidian: 0, geode: 0 },
                Resource { ore: 1, clay: 0, obsidian: 0, geode: 0 },
                1
            )];
            let maxes = blueprint.iter()
                .fold(Resource { ore: 0, clay: 0, obsidian: 0, geode: 0 }, |max, (cost, _)| {
                    Resource { ore: max.ore.max(cost.ore), clay: max.clay.max(cost.clay), obsidian: max.obsidian.max(cost.obsidian), geode: u16::MAX }
                });
            for _ in 0..24 {
                states = states.into_iter()
                    .flat_map(|(state, robots, last)| {
                        blueprint.iter()
                            .enumerate()
                            .filter(move |(which, (cost, _))| {
                                if *which == 0 {
                                    true
                                } else if last == 0 {
                                    let last_state = state - robots;
                                    state >= *cost && !(last_state >= *cost) // strictly better to take this action last turn
                                } else {
                                    state >= *cost
                                }
                            })
                            .filter(move |(which, _)| {
                                if *which == 0 {
                                    true
                                } else {
                                    match *which {
                                        1 => robots.ore < maxes.ore,
                                        2 => robots.clay < maxes.clay,
                                        3 => robots.obsidian < maxes.obsidian,
                                        4 => true,
                                        _ => unreachable!()
                                }}
                            })
                            .map(move |(which, (cost, benefit))| {
                                ((state - *cost) + robots, robots + *benefit, which)
                            })
                    })
                    .collect();
            }
            states.into_iter()
                .fold(0, |max, (state, _, _)| {
                max.max(state.geode)
            })
        })
        .enumerate()
        .fold(0, |prev, (num, count)| {
            prev + (num as u16 + 1) * count
        })
}

// #[cfg(test)]
// mod tests {
//     use crate::best_paths;

//     const INPUT: &str = "Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
// Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian.
// ";

    // #[test]
    // fn count_paths() {
        // let count = best_paths(INPUT);
        // assert_eq!(33, count);
    // }
// }
