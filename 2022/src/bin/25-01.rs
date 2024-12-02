use std::{fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("25.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = encode(input.lines()
        .map(decode)
        .sum());
    println!("{}", output);
    println!("time elapsed, {}ms", now.elapsed().as_millis());
}

fn decode(string: &str) -> u64 {
    string.chars()
        .rev()
        .enumerate()
        .fold(0, |num, (idx, ch)| {
            let base: usize = 5;
            let place: i64 = base.pow(idx.try_into().unwrap()).try_into().unwrap();
            num + place * match ch {
                '2' => 2,
                '1' => 1,
                '0' => 0,
                '-' => -1,
                '=' => -2,
                _ => unreachable!(),
            }
        }).try_into().unwrap()
}

fn encode(num: u64) -> String {
    let mut num = num;
    let mut output = String::new();
    while num != 0 {
        let carry;
        match num % 5 {
            0 => {
                output.push('0');
                carry = 0;
            },
            1 => {
                output.push('1');
                carry = 0;
            },
            2 => {
                output.push('2');
                carry = 0;
            },
            3 => {
                output.push('=');
                carry = 2;
            },
            4 => {
                output.push('-');
                carry = 1;
            },
            _ => unreachable!(),
        }
        num += carry;
        num /= 5;
    }
    output.chars().rev().collect()
}

#[cfg(test)]
mod tests {
    use crate::{decode, encode};

    const INPUT: &str ="1=-0-2
12111
2=0=
21
2=01
111
20012
112
1=-1=
1-12
12
1=
122
";

    #[test]
    fn test_coding() {
        let v: Vec<_> = INPUT.lines()
            .map(decode)
            .collect();
        let w = vec![1747, 906, 198, 11, 201, 31, 1257, 32,353, 107, 7, 3, 37];
        assert_eq!(v, w);
        let u: Vec<_> = w.iter()
            .copied()
            .map(encode)
            .inspect(|line| println!("{}", line))
            .collect();
        assert!(std::iter::zip(u.iter(), INPUT.lines()).all(|(s, t)| {
            s == t
        }));
    }
}
