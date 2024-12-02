use std::{collections::HashSet, fs::File, io::Read, ops::Add, path::Path, time::Instant};

fn main() {
    let path = Path::new("18.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let droplets = parse(&input);
    let count = count_exposed(&droplets);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

#[derive(Hash, Eq, PartialEq, Clone, Copy)]
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

fn count_exposed(droplets: &HashSet<Droplet>) -> usize {
    droplets.iter()
        .map(|droplet| {
            droplet.neighbors()
                .into_iter()
                .filter(|neighbor| !droplets.contains(neighbor))
                .count()
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use crate::{count_exposed, parse};

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
        let count = count_exposed(&droplets);
        assert_eq!(count, 64);
    }
}
