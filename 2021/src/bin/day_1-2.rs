use std::{fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("01.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = process_pt_2(&input);
    println!("{}", output);
    println!("time elapsed: {}us", now.elapsed().as_micros());
}

fn process_pt_2(input: &str) -> usize {
    let mut window: [i32;3] = [ 0, 0, 0 ];
    let mut idx = 0;
    let mut last = 0;
    input.lines()
        .map(|line| line.parse::<i32>().expect("number expected!"))
        .map(|x| {
            window[idx] = x;
            idx = (idx + 1) % 3;
            window.clone()
        })
        .filter_map(|window| {
            if window.iter().any(|x| x == &0) {
                None
            } else {
                Some(window.iter().sum())
            }
        })
        .filter(|&x| {
            let l = last;
            last = x;
            l > 0 && x > l
        })
        .count()
}

#[cfg(test)]
mod tests {
    use crate::process_pt_2;

    const INPUT: &str = "199
200
208
210
200
207
240
269
260
263
";

    #[test]
    fn it_works_part_two() {
        let output = process_pt_2(INPUT);
        assert_eq!(5, output);
    }
}
