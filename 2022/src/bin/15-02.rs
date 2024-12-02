use std::{cmp::Ordering, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("15.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let (x, y) = find_missing_beacon(&input, 4_000_000);
    let tuning_frequency = x * 4_000_000 + y;
    println!("{}", tuning_frequency);
    println!("time elapsed: {}ms", now.elapsed().as_millis())
}

struct Sensor {
    location: (i64, i64),
    radius: i64,
}

impl Sensor {
    fn from(input: &str) -> Option<Self> {
        let (x_str, rem1) = input.trim_start_matches("Sensor at x=").split_once(", y=")?;
        let x: i64 = x_str.parse().ok()?;
        let (y_str, rem2) = rem1.split_once(": closest beacon is at x=")?;
        let y: i64 = y_str.parse().ok()?;
        let (x_end, y_end) = rem2.split_once(", y=")?;
        Some(Sensor { location: (x, y), radius: (x - x_end.parse::<i64>().ok()?).abs() + (y - y_end.parse::<i64>().ok()?).abs() })
    }

    fn excludes(&self, y_coord: i64) -> Option<(i64, i64)> {
        let rem = self.radius - (self.location.1 - y_coord).abs();
        if rem <= 0 { None } else { Some((self.location.0 - rem, self.location.0 + rem)) }
    }
}

fn overlap(a: &(i64, i64), b: &(i64, i64)) -> bool {
    match a.0.cmp(&b.0) {
        Ordering::Less => a.1 >= b.0,
        Ordering::Equal => true,
        Ordering::Greater => b.1 >= a.0,
    }
}

fn find_missing_beacon(input: &str, bounding_box: i64) -> (i64, i64) {
    let sensors: Vec<_> = input.lines()
        .filter_map(Sensor::from)
        .collect();
    for y in 0..=bounding_box {
        let vec: Vec<_> = sensors.iter()
            .filter_map(|sensor| sensor.excludes(y))
            .collect();
        let coalesced = vec.iter()
            .fold(vec![], |res, range| {
                let mut r = *range;
                let mut new: Vec<_> = res.into_iter()
                    .filter(|other| {
                        let o = overlap(&r, other);
                        if o { r = (r.0.min(other.0), r.1.max(other.1)); }
                        !o
                    })
                    .collect();
                new.push(r);
                new
            });
        if coalesced.iter().any(|(left, right)| (*left <= 0 && *right >= bounding_box) ) {
            continue;
        }
        let x = (0..=bounding_box)
            .filter(|&x| !coalesced.iter().any(|range| range.0 <= x && x <= range.1))
            .nth(0).unwrap();
        return (x, y);
    }
    panic!("no beacons missing!");
}

#[cfg(test)]
mod tests{
    use crate::find_missing_beacon;

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
        let beacon = find_missing_beacon(INPUT, 20);
        assert_eq!(beacon, (14, 11));
    }
}
