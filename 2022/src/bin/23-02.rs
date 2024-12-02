use std::{collections::HashMap, fs::File, io::Read, ops::Add, path::Path, time::Instant};

fn main() {
    let path = Path::new("23.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = solve(&input);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

#[derive(Copy, Clone, Hash, Eq, PartialEq, Debug)]
struct Elf {
    x: i64,
    y: i64,
}

impl Add for Elf {
    type Output = Elf;

    fn add(self, rhs: Self) -> Self::Output {
        Self::Output {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
        }
    }
}

fn parse(input: &str) -> Vec<Elf> {
    input.lines()
        .enumerate()
        .flat_map(|(y, line)| {
            line.chars()
                .enumerate()
                .filter_map(move |(x, ch)| {
                    let x: i64 = x.try_into().unwrap();
                    let y: i64 = y.try_into().unwrap();
                    if ch == '#' { Some(Elf{ x, y }) } else { None }
                })
        })
        .collect()
}

fn round(elves: &mut Vec<Elf>, round_id: usize) -> bool {
    const CONSIDERATION: &[&[Elf]] = &[
        &[ Elf { x: -1, y: -1 }, Elf { x: 0, y: -1 }, Elf { x: 1, y: -1 } ],
        &[ Elf { x: -1, y: 1 }, Elf { x: 0, y: 1 }, Elf { x: 1, y: 1 } ],
        &[ Elf { x: -1, y: -1 }, Elf { x: -1, y: 0 }, Elf { x: -1, y: 1 } ],
        &[ Elf { x: 1, y: -1 }, Elf { x: 1, y: 0 }, Elf { x: 1, y: 1 } ],
    ];
    const NEIGHBORS: &[Elf] = &[
        Elf { x: -1, y: -1 }, Elf { x: 0, y: -1 }, Elf { x: 1, y: -1 },
        Elf { x: -1, y: 0 },                       Elf { x: 1, y: 0 },
        Elf { x: -1, y: 1 },  Elf { x: 0, y: 1 },  Elf { x: 1, y: 1 },
    ];
    let map: HashMap<_,_> = elves.iter()
        .copied()
        .enumerate()
        .map(|(id, elf)| (elf, id))
        .collect();
    let mut new_map = HashMap::new();
    elves.iter()
        .enumerate()
        .filter(|(_, elf)| {
            NEIGHBORS.iter().any(|&neighbor| {
                map.contains_key(&(neighbor + **elf))
            })
        })
        .filter_map(|(id, elf)|{
            let next = CONSIDERATION.iter()
                .enumerate()
                .cycle()
                .skip(round_id)
                .take(4)
                .filter(|(_, &list)| {
                    !list.iter()
                        .any(|&neighbor| {
                            map.contains_key(&(neighbor + *elf))
                        })
                        })
                .map(|(dir, _)| match dir {
                    0 => *elf + Elf { x: 0, y: -1 },
                    1 => *elf + Elf { x: 0, y: 1 },
                    2 => *elf + Elf { x: -1, y: 0 },
                    3 => *elf + Elf { x: 1, y: 0 },
                    _ => unreachable!(),
                })
                .nth(0)?;
            Some((id, next))
        })
        .for_each(|(id, next)| {
            if new_map.contains_key(&next) {
                new_map.insert(next, None);
            } else {
                new_map.insert(next, Some(id));
            }
        });
    if new_map.iter()
        .all(|(_, val)| val.is_none()) {
            return true;
        }
    for (key, id) in new_map.into_iter()
        .filter_map(|(key, val)| {
            let id = val?;
            Some((key, id))
        }) {
            elves[id] = key;
        }
    false
}

fn solve(input: &str) -> usize {
    let mut elves = parse(input);
    let mut id = 0;
    while !round(&mut elves, id) { id += 1; }
    id + 1
}

// fn display(elves: &Vec<Elf>) -> String {
//     let (x_min, x_max, y_min, y_max) = dimensions(elves);
//     let set: HashSet<_> = elves.iter().copied().collect();
//     let mut output = String::new();
//     for y in y_min..=y_max {
//         for x in x_min..=x_max {
//             if set.contains(&Elf { x, y }) {
//                 output.push('#');
//             } else {
//                 output.push('.');
//             }
//         }
//         output.push('\n');
//     }
//     output
// }

#[cfg(test)]
mod tests {
    use crate::solve;

    const INPUT: &str = "....#..
..###.#
#...#.#
.#...##
#.###..
##.#.##
.#..#..
";

    #[test]
    fn count() {
        let count = solve(INPUT);
        assert_eq!(20, count);
    }
}
