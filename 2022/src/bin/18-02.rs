use std::{collections::{HashMap, HashSet}, fs::File, io::Read, ops::Add, path::Path, time::Instant};

use itertools::Itertools;

fn main() {
    let path = Path::new("18.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let droplets = parse(&input);
    let neighbors = exposed(&droplets);
    let count = count(&droplets, &neighbors);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

#[derive(Hash, Eq, PartialEq, Clone, Copy, Debug)]
struct Droplet { x: i32, y: i32, z: i32 }

impl Add for Droplet {
    type Output = Droplet;

    fn add(self, rhs: Self) -> Self::Output {
        Self {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
            z: self.z + rhs.z
        }
    }
}

impl Droplet {
    fn neighbors(&self) -> Vec<Self> {
        const NEIGHBORS: &[Droplet] = &[
            Droplet { x: -1, y: 0, z: 0 },
            Droplet { x: 1, y: 0, z: 0 },
            Droplet { x: 0, y: -1, z: 0 },
            Droplet { x: 0, y: 1, z: 0 },
            Droplet { x: 0, y: 0, z: -1 },
            Droplet { x: 0, y: 0, z: 1 },
        ];
        NEIGHBORS.iter()
            .map(|rhs| *self + *rhs)
            .collect()
    }
}

fn parse(input: &str) -> HashSet<Droplet> {
    input.lines()
        .map(|line| {
            let vec: Vec<_> = line.split(',')
                .map(|token| token.parse().unwrap())
                .collect();
            Droplet{
                x: vec[0], y: vec[1], z: vec[2]
            }
        })
        .collect()
}

fn exposed(droplets: &HashSet<Droplet>) -> HashMap<Droplet, usize> {
    let mut ret = HashMap::new();
    droplets.iter()
        .flat_map(|droplet| {
            droplet.neighbors()
                .into_iter()
                .filter(|neighbor| !droplets.contains(neighbor))
        })
        .for_each(|droplet| {
            match ret.get(&droplet) {
                Some(count) => ret.insert(droplet, *count + 1),
                None => ret.insert(droplet, 1),
            };
        });
    ret
}

fn count(droplets: &HashSet<Droplet>, exposed: &HashMap<Droplet, usize>) -> usize {
    let min = Droplet {
        x: droplets.iter()
            .map(|droplet| droplet.x)
            .min().unwrap(),
        y: droplets.iter()
            .map(|droplet| droplet.y)
            .min().unwrap(),
        z: droplets.iter()
            .map(|droplet| droplet.z)
            .min().unwrap(),
    };
    let max = Droplet {
        x: droplets.iter()
            .map(|droplet| droplet.x)
            .max().unwrap(),
        y: droplets.iter()
            .map(|droplet| droplet.y)
            .max().unwrap(),
        z: droplets.iter()
            .map(|droplet| droplet.z)
            .max().unwrap(),
    };
    exposed.iter()
        .filter(|(droplet, _)| {
            let mut dead = HashSet::new();
            let mut alive = vec![**droplet];
            while alive.len() > 0 {
                for living in alive.iter() {
                    if living.x < min.x || living.x > max.x || living.y < min.y || living.y > max.y || living.z < min.z || living.z > max.z {
                        return true;
                    }
                    dead.insert(*living);
                }
                alive = alive.iter()
                    .flat_map(|droplet| droplet.neighbors())
                    .unique()
                    .filter(|droplet| !droplets.contains(droplet) && !dead.contains(droplet))
                    .collect();
            }
            false
        })
        .map(|(_, count)| *count)
        .sum()
}

#[cfg(test)]
mod tests {
    use crate::{count, exposed, parse};

    const INPUT: &str = "2,2,2
1,2,2
3,2,2
2,1,2
2,3,2
2,2,1
2,2,3
2,2,4
2,2,6
1,2,5
3,2,5
2,1,5
2,3,5
";

    #[test]
    fn counting() {
        let droplets = parse(INPUT);
        let neighbors = exposed(&droplets);
        let count = count(&droplets, &neighbors);
        assert_eq!(count, 58);
    }
}
