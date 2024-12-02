use std::{collections::HashSet, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("14.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = SandIter::from(&input)
        .count();
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

fn parse(input: &str) -> Vec<Vec<(i64, i64)>> {
    input.lines()
        .map(|line| {
            line.split(" -> ")
                .map(|token| {
                    let (x, y) = token.split_once(',').unwrap();
                    (x.parse().unwrap(), y.parse().unwrap())
                })
                .collect()
        })
        .collect()
}

struct SandIter {
    sand: HashSet<(i64, i64)>,
    max_y: i64,
}

impl SandIter {
    fn from(string: &str) -> Self {
        let rocks = parse(string);
        let max_y = rocks.iter()
            .map(|vec| {
                vec.iter()
                    .fold(0, |i, (_, y)| {
                        i.max(*y)
                    })
            })
            .max()
            .unwrap();
        let sand: HashSet<_> = rocks.iter()
            .map(|bar|
                 bar.windows(2)
                 .map(|window| {
                     let (x1, y1) = window[0];
                     let (x2, y2) = window[1];
                     if x1 == x2 {
                         (y1.min(y2)..=y1.max(y2)).map(|y| {
                             (x1, y)
                         }).collect::<Vec<_>>()
                     } else {
                         (x1.min(x2)..=x1.max(x2)).map(|x| {
                             (x, y1)
                         }).collect::<Vec<_>>()
                     }
                 })
                 .flatten()
            )
            .flatten()
            .collect();
        Self { sand, max_y }
    }
}

impl Iterator for SandIter {
    type Item = (i64, i64);

    fn next(&mut self) -> Option<Self::Item> {
        let mut rock = (500, 0);
        loop {
            let y = rock.1 + 1;
            if rock.1 > self.max_y { return None; }
            let next = vec![(rock.0, y), (rock.0 - 1, y), (rock.0 + 1, y)];
            let keep_going: Vec<_> = next.into_iter()
                .filter(|r| {
                    self.sand.get(r) == None
                })
                .collect();
            match keep_going.get(0) {
                Some(r) => rock = *r,
                None => {
                    self.sand.insert(rock);
                    return Some(rock);
                },
            }; 
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::SandIter;

    const INPUT: &str = "498,4 -> 498,6 -> 496,6
503,4 -> 502,4 -> 502,9 -> 494,9
";

    #[test]
    fn parse_and_flood() {
        let count = SandIter::from(INPUT)
            .count();
        assert_eq!(count, 24);
    }
}
