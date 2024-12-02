use std::{fs::File, io::Read, path::Path};

use itertools::Itertools;

fn main() {
    let path = Path::new("12.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let (map, start_x, start_y, end_x, end_y) = Map::from(&input);
    let len = flood(&map, start_x, start_y, end_x, end_y);
    println!("{}", len);
}

struct Map {
    data: Vec<u8>,
    width: usize,
    height: usize,
}

impl Map {
    fn from(input: &str) -> (Map, usize, usize, usize, usize) {
        let lines: Vec<_> = input.lines().collect();
        assert!(lines.iter()
            .map(|line| {
                line.len()
            })
                .all_equal());
        let width = lines[0].len();
        let height = lines.len();
        let mut x = 0;
        let mut y = 0;
        let mut end_x = 0;
        let mut end_y = 0;
        let data: Vec<u8> = lines.iter().enumerate()
            .map(|(i, l)| {
                 l.chars().enumerate().map(|(j, ch)| {
                     match ch {
                         'a'..='z' => ((ch as u32) - ('a' as u32)) as u8,
                         'S' => {
                             x = j;
                             y = i;
                             0
                         },
                         'E' => {
                             end_x = j;
                             end_y = i;
                             25
                         },
                         _ => panic!("bad parse!"),
                     }
                 })
                .collect::<Vec<_>>()
            })
            .flatten()
            .collect();
        (Map { data, width, height }, x, y, end_x, end_y)
    }

    fn mask(&self, x: usize, y: usize) -> usize {
        assert!(x < self.width);
        assert!(y < self.height);
        y * self.width + x
    }

    // fn mask2(&self, idx: usize) -> (usize, usize) {
    // assert!(idx < self.data.len());
    // (idx % self.width, idx / self.width)
    // }
}

struct Flooder<'a> {
    map: &'a Map,
    paths: Vec<bool>,
    active: Vec<(usize, usize)>,
}

impl<'a> Flooder<'a> {
    fn new(map: &'a Map, start_x: usize, start_y: usize) -> Self {
        let mut paths = vec![false; map.data.len()];
        paths[map.mask(start_x, start_y)] = true;
        Flooder { map, paths, active: vec![(start_x, start_y)] }
    }
}

fn flood(map: &Map, start_x: usize, start_y: usize, end_x: usize, end_y: usize) -> usize {
    Flooder::new(map, start_x, start_y)
        .take_while(|output| {
            !output.iter().any(|(x, y)| {
                *x == end_x && *y == end_y
            })
        })
        .count() + 1
}

impl<'a> Iterator for Flooder<'a> {
    type Item = Vec<(usize, usize)>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.active.len() == 0 {
            return None;
        }
        let new: Vec<_> = self.active.iter()
            .map(|(x, y)| {
                let mut v = Vec::new();
                let idx = self.map.mask(*x, *y);
                let height = self.map.data[idx];
                if *x > 0 { v.push((*x - 1, *y, height)); }
                if *x < self.map.width - 1 { v.push((*x + 1, *y, height)); }
                if *y > 0 { v.push((*x, *y - 1, height)); }
                if *y < self.map.height - 1 { v.push((*x, *y + 1, height)); }
                v
            })
            .flatten()
            .filter_map(|(x, y, h)| {
                let idx = self.map.mask(x, y);
                if self.map.data[idx] > h + 1 { None } else { Some((x, y)) }
            })
            .unique()
            .filter(|(x, y)| {
                !self.paths[self.map.mask(*x, *y)]
            })
            .collect();
        for (x, y) in new.iter() {
            self.paths[self.map.mask(*x, *y)] = true;
        }
        self.active = new;
        Some(self.active.clone())
    }
}

#[cfg(test)]
mod tests {
    use crate::{flood, Map};

    const INPUT: &str = "Sabqponm
abcryxxl
accszExk
acctuvwj
abdefghi
";

    #[test]
    fn test_flood() {
        let (map, start_x, start_y, end_x, end_y) = Map::from(INPUT);
        let len = flood(&map, start_x, start_y, end_x, end_y);
        assert_eq!(len, 31);
    }
}
