use std::{fs::File, io::Read, path::Path, time::Instant};

use itertools::Itertools;

fn main() {
    let path = Path::new("15.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = excluded(&input, 2_000_000) - count_beacons(&input, 2_000_000);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis())
}

struct Sensor {
    location: (i64, i64),
    radius: i64,
}

impl Sensor {
    fn excludes(&self, y_coord: i64) -> Vec<i64> {
        ((self.location.0 - self.radius)..=(self.location.0 + self.radius))
            .filter(|x| (x - self.location.0).abs() + (y_coord - self.location.1).abs() <= self.radius)
            .collect()
    }

    fn from(input: &str) -> Option<Self> {
        let (x_str, rem1) = input.trim_start_matches("Sensor at x=").split_once(", y=")?;
        let x: i64 = x_str.parse().ok()?;
        let (y_str, rem2) = rem1.split_once(": closest beacon is at x=")?;
        let y: i64 = y_str.parse().ok()?;
        let (x_end, y_end) = rem2.split_once(", y=")?;
        Some(Sensor { location: (x, y), radius: (x - x_end.parse::<i64>().ok()?).abs() + (y - y_end.parse::<i64>().ok()?).abs() })
    }
}

fn excluded(input: &str, y_coord: i64) -> usize {
    input.lines()
        .filter_map(Sensor::from)
        .map(|sensor| sensor.excludes(y_coord))
        .flatten()
        .unique()
        .count()
}

fn count_beacons(input: &str, y_coord: i64) -> usize {
    input.lines()
        .filter_map(|line| {
            let (pref, y_str) = line.rsplit_once(", y=")?;
            let (_, x_str) = pref.rsplit_once("x=")?;
            Some((x_str.parse::<i64>().ok()?, y_str.parse::<i64>().ok()?))
        })
        .filter(|(_, y)| y == &y_coord)
        .unique()
        .count()
}

#[cfg(test)]
mod tests{
    use crate::{count_beacons, excluded};

    const INPUT: &str = "Sensor at x=2, y=18: closest beacon is at x=-2, y=15
Sensor at x=9, y=16: closest beacon is at x=10, y=16
Sensor at x=13, y=2: closest beacon is at x=15, y=3
Sensor at x=12, y=14: closest beacon is at x=10, y=16
Sensor at x=10, y=20: closest beacon is at x=10, y=16
Sensor at x=14, y=17: closest beacon is at x=10, y=16
Sensor at x=8, y=7: closest beacon is at x=2, y=10
Sensor at x=2, y=0: closest beacon is at x=2, y=10
Sensor at x=0, y=11: closest beacon is at x=2, y=10
Sensor at x=20, y=14: closest beacon is at x=25, y=17
Sensor at x=17, y=20: closest beacon is at x=21, y=22
Sensor at x=16, y=7: closest beacon is at x=15, y=3
Sensor at x=14, y=3: closest beacon is at x=15, y=3
Sensor at x=20, y=1: closest beacon is at x=15, y=3
";

    #[test]
    fn count_excluded() {
        let count = excluded(INPUT, 10) - count_beacons(INPUT, 10);
        assert_eq!(count, 26);
    }
}
