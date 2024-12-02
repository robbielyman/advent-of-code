use std::{fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("20.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let output = mix(&input);
    println!("{}", output);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

fn mix(input: &str) -> i64 {
    let file: Vec<i64> = input.lines()
        .map(|line| line.parse().unwrap())
        .map(|i: i64| i * 811589153)
        .collect();
    let mut output: Vec<_> = file.iter()
        .enumerate()
        .map(|(idx, _)| idx)
        .collect();
    for _ in 0..10 {
        file.iter()
        .copied()
        .enumerate()
        .for_each(|(index, amount)| {
            let closure = rotate(output[index], file.len(), amount);
            output.iter_mut()
                .for_each(closure);
        });
    }
    let mut mixed_file = vec![0; file.len()];
    for (&val, &idx) in std::iter::zip(file.iter(), output.iter()) {
        if idx as usize >= file.len() {
            panic!("bad input for key: {}, index: {}", val, idx);
        }
        mixed_file[idx as usize] = val;
    }
    let mut index = mixed_file.iter().take_while(|&&val| val != 0).count();
    let mut sum = 0;
    for _ in 0..3 {
        index = (index + 1000) % mixed_file.len();
        sum += mixed_file[index];
    }
    sum
}

fn wrap(num: i64, len: usize) -> usize {
    let mut ret = num % (len - 1) as i64;
    while ret <= 0 {
        ret += (len - 1) as i64; 
    }
    ret as usize
}

fn rotate(idx: usize, len: usize, amount: i64) -> Box<dyn Fn(&mut usize)> {
    let endpt = wrap(idx as i64 + amount, len);
    if idx <= endpt {
        Box::new(move |input| {
            if *input == idx {
                *input = endpt;
            } else if idx < *input && *input <= endpt {
                *input -= 1
            }
        })
    } else {
        Box::new(move |input| {
            if *input == idx {
                *input = endpt;
            } else if endpt <= *input && *input < idx {
                *input += 1
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use crate::mix;

    const INPUT: &str = "1
2
-3
3
-2
0
4
";

    #[test]
    fn it_works() {
        let output = mix(INPUT);
        assert_eq!(1623178306, output);
    }
}
