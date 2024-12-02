use std::{cmp::Ordering, fs::File, io::Read, path::Path};

fn main() {
    let path = Path::new("13.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let sum: usize = input.split("\n\n")
        .map(|line| {
            let (left_str, right_str) = line.split_once('\n').expect("no newline");
            let left = Elem::from(left_str);
            let right = Elem::from(right_str);
            left.cmp(&right)
        })
        .enumerate()
        .filter(|(_, o)| *o == Ordering::Less)
        .map(|(i, _)| i + 1)
        .sum();
    println!("{}", sum);
}

#[derive(Eq)]
enum Elem {
    Int(i32),
    List(Vec<Elem>)
}

impl PartialEq for Elem {
    fn eq(&self, other: &Self) -> bool {
        match self {
            Self::Int(i) => if let Self::Int(j) = other { i == j } else { false },
            Self::List(v) => if let Self::List(w) = other {
                v.len() == w.len() && v.iter().zip(w.iter()).all(|(e1, e2)| { e1 == e2 })
            } else { false }
        }
    }
}

impl PartialOrd for Elem {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Elem {
    fn cmp(&self, other: &Self) -> Ordering {
        match self {
            Self::Int(i) => match other {
                Self::Int(j) => i.cmp(j),
                Self::List(_) => Self::List(vec![Self::Int(*i)]).cmp(other),
            },
            Self::List(v) => match other {
                Self::Int(j) => self.cmp(&Self::List(vec![Self::Int(*j)])),
                Self::List(w) => {
                    for (e1, e2) in v.iter().zip(w.iter()) {
                        match e1.cmp(e2) {
                            Ordering::Less => return Ordering::Less,
                            Ordering::Greater => return Ordering::Greater,
                            Ordering::Equal => {},
                        };
                    }
                    v.len().cmp(&w.len())
                }
            },
        }
    }
}

struct ElemIter<'a> {
    data: &'a [u8],
    idx: usize,
}

impl<'a> ElemIter<'a> {
    fn new(data: &'a [u8]) -> Self {
        Self { data, idx: 0 }
    }
}

impl<'a> Iterator for ElemIter<'a> {
    type Item = Elem;

    fn next(&mut self) -> Option<Self::Item> {
        if self.idx >= self.data.len() {
            return None;
        }
        let bytes = self.data;
        if bytes[self.idx] != b'[' {
            let len = bytes[self.idx..].iter()
                .take_while(|b| {
                    **b != b','
                })
                .count();
            let ret: i32 = std::str::from_utf8(&bytes[self.idx .. self.idx + len])
                .expect("bad utf8").parse().expect("failed to parse!");
            self.idx += len + 1;
            return Some(Self::Item::Int(ret));
        }
        let mut level = 1;
        let len = bytes[self.idx + 1 ..].iter()
            .map(|byte| {
                match *byte {
                    b'[' => level += 1,
                    b']' => level -= 1,
                    _ => {},
                };
                level
            })
            .take_while(|l| *l > 0)
            .count();
        let v: Vec<_> = ElemIter::new(&bytes[self.idx + 1 .. self.idx + 1 + len]).collect();
        self.idx += len + 3;
        Some(Self::Item::List(v))
    }
}

impl Elem {
    fn from(string: &str) -> Elem {
        Self::List(ElemIter::new(string.as_bytes()).collect())
    }
}

#[cfg(test)]
mod tests {
    use std::cmp::Ordering;

    use crate::Elem;

    const INPUT: &str = "[1,1,3,1,1]
[1,1,5,1,1]

[[1],[2,3,4]]
[[1],4]

[9]
[[8,7,6]]

[[4,4],4,4]
[[4,4],4,4,4]

[7,7,7,7]
[7,7,7]

[]
[3]

[[[]]]
[[]]

[1,[2,[3,[4,[5,6,7]]]],8,9]
[1,[2,[3,[4,[5,6,0]]]],8,9]
";

    #[test]
    fn parse_and_order() {
        let res: Vec<_> = INPUT.split("\n\n")
            .map(|sub| {
                let (left_str, right_str) = sub.split_once('\n').unwrap();
                let left = Elem::from(left_str);
                let right = Elem::from(right_str);
                left.cmp(&right)
            })
            .collect();
        assert_eq!(res, vec![Ordering::Less, Ordering::Less, Ordering::Greater,
                             Ordering::Less, Ordering::Greater, Ordering::Less,
                             Ordering::Greater, Ordering::Greater]);
        let sum: usize = res.into_iter()
            .enumerate()
            .filter(|(_, o)| *o == Ordering::Less)
            .map(|(i, _)| i + 1)
            .sum();
        assert_eq!(sum, 13);
    }
}
