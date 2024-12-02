use std::{collections::HashMap, fmt::Display, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("17.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = height_after(input.trim_end_matches('\n'), 1_000_000_000_000); // 1_000_000_000_000);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

fn height_after(input: &str, num: usize) -> usize {
    let rocks = Shape::generate().into_iter().enumerate().cycle();
    let mut cycler = input.trim_end_matches('\n').chars().enumerate().cycle();
    let mut states = HashMap::new();
    let mut tower = Vec::new();
    let mut repeat_idx = None;
    let delta_vec: Vec<_> = rocks
        .map(|(rocks_idx, shape)| {
            let mut rock = shape;
            let mut height = tower.len() + 3;
            let mut cycle_idx;
            loop {
                let (j, ch) = cycler.next().unwrap();
                cycle_idx = j;
                match ch {
                    '<' => if !rock.overlap(&Shape::left_mask()) {
                        let new = Shape(rock.0 << 1);
                        let other = Shape::from_tower(&tower, height);
                        if !new.overlap(&other) {
                            rock = new;
                        }
                    },
                    '>' => if !rock.overlap(&Shape::right_mask()) {
                        let new = Shape(rock.0 >> 1);
                        let other = Shape::from_tower(&tower, height);
                        if !new.overlap(&other) {
                            rock = new;
                        }
                    },
                    _ => unreachable!(),
                }
                if height == 0 { break; }
                let other = Shape::from_tower(&tower, height - 1);
                if rock.overlap(&other) { break; }
                height -= 1;
            }
            let height_delta = rock.push(&mut tower, height);
            (State {
                top: top(&tower),
                rocks_idx,
                cycle_idx
            }, height_delta)
        })
        .enumerate()
        // .inspect(|(idx, (state, _))| {
            // if *idx == 101 {
                // println!("{}", state);
            // }
        // }) 
        .take_while(|(idx, (state, _))| {
            if *idx >= num { return false; }
            match states.insert((*state).clone(), *idx) {
                None => true,
                Some(repeat) => {
                    repeat_idx = Some(repeat);
                    false
                },
            }
        })
        .map(|(_, (_, delta))| delta)
        // .map(|(_, delta)| delta)
        .collect();
    if repeat_idx.is_none() {
        return delta_vec.iter().sum::<usize>();
    }
    let cycle_len = delta_vec.len() - repeat_idx.unwrap();
    let cycle_height: usize = delta_vec[repeat_idx.unwrap()..].iter().sum();
    let rem = num - delta_vec.len();
    let sum = delta_vec.iter().sum::<usize>() + (cycle_height * (rem / cycle_len));
    sum + delta_vec[repeat_idx.unwrap()..].iter()
        .take(rem % cycle_len)
        .sum::<usize>()
}

fn top(tower: &Vec<u8>) -> Vec<u8> {
    tower.iter()
        .rev()
        .copied()
        .take_while(|byte| *byte != 0x7f)
        .collect()
}

#[derive(Hash, PartialEq, Eq, Clone, Debug)]
struct State {
    top: Vec<u8>,
    rocks_idx: usize,
    cycle_idx: usize,
}

impl Display for State {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut output = String::new();
        self.top.iter()
            .for_each(|&byte| {
                (0..7).rev()
                    .for_each(|i| {
                        if byte & (1 << i) != 0 {
                            output.push('#')
                        } else {
                            output.push('.')
                        }
                    });
                output.push('\n');
            });
        write!(f, "{}rocks: {}, cycle: {}\n", output, self.rocks_idx, self.cycle_idx)
    }
}

#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq)]
struct Shape(u32);

impl Shape {
    fn push(&self, tower: &mut Vec<u8>, height: usize) -> usize {
        let len = tower.len();
        for i in 0..4 {
            if self.row(i) == 0x00 { break; }
            if height + i < tower.len() {
                tower[height + i] = tower[height + i] | self.row(i);
            } else {
                tower.push(self.row(i));
            }
        }
        tower.len() - len
    }
    
    fn generate() -> [Self; 5] {
        [
            // x....... = 0x00
            // x....... = 0x00
            // x....... = 0x00
            // x..####. = 0x1e
            Self(0x0000001e),
            // x....... = 0x00
            // x...#... = 0x08
            // x..###.. = 0x1c
            // x...#... = 0x08
            Self(0x00081c08),
            // x....... = 0x00
            // x....#.. = 0x04
            // x....#.. = 0x04
            // x..###.. = 0x1c
            Self(0x0004041c),
            // x..#.... = 0x10
            // x..#.... = 0x10
            // x..#.... = 0x10
            // x..#.... = 0x10
            Self(0x10101010),
            // x....... = 0x00
            // x....... = 0x00
            // x..##... = 0x18
            // x..##... = 0x18
            Self(0x00001818)
        ]
    }

    #[inline]
    fn left_mask() -> Self {
        Self(0x40404040)
    }

    #[inline]
    fn right_mask() -> Self {
        Self(0x01010101)
    }

    #[inline]
    fn from(chunk: &[u8; 4]) -> Self {
        let a: u32 = chunk[0].into();
        let b: u32 = chunk[1].into();
        let c: u32 = chunk[2].into();
        let d: u32 = chunk[3].into();
        Self(a << 24 | b << 16 | c << 8 | d)
    }

    #[inline]
    fn overlap(&self, other: &Self) -> bool {
        self.0 & other.0 != 0
    }

    #[inline]
    fn row(&self, which: usize) -> u8 {
        match which {
            0 => self.0 & 0x000000ff,
            1 => (self.0 & 0x0000ff00) >> 8,
            2 => (self.0 & 0x00ff0000) >> 16,
            3 => (self.0 & 0xff000000) >> 24,
            _ => unreachable!()
        }.try_into().unwrap()
    }

    fn from_tower(tower: &Vec<u8>, height: usize) -> Self {
        let mut ret = [0; 4];
        if height >= tower.len() { return Self(0); }
        for i in (0..4).rev() {
            if height + i >= tower.len() { continue; }
            ret[3 - i] = tower[height + i];
        }
        Self::from(&ret)
    }
}

#[cfg(test)]
mod tests {
    use crate::Shape;

    #[test]
    fn bitmunging() {
        let shapes = Shape::generate();
        let ok: Vec<_> = shapes.iter()
            .map(|shape| {
                let bytes = &[shape.row(3), shape.row(2), shape.row(1), shape.row(0)];
                let other = Shape::from(bytes);
                *shape == other
            })
            .collect();
        assert_eq!(vec![true, true, true, true, true], ok);
    }
}
