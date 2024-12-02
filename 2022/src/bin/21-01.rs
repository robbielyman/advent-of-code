use std::{collections::HashMap, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("21.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let mut monkeys = Monkalc::from(&input);
    let count = monkeys.listen_for("root");
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

struct Monkalc {
    data: HashMap<String, Result>
}

impl Monkalc {
    fn from(input: &str) -> Self {
        Self {
            data: input.lines()
                .map(|line| {
                    let (name, operation) = line.split_once(": ").unwrap();
                    (name.into(), Result::from(operation))
                })
                .collect()
        }
    }

    fn listen_for(&mut self, name: &str) -> i64 {
        let reference = self.data.get(name).unwrap().clone();
        match reference {
            Result::Done(num) => num,
            Result::Undone(token) => {
                let [first, op, second] = (&token).split_whitespace().collect::<Vec<&str>>()[0..3] else {
                    panic!("bad token {}", token);
                };
                let a = self.listen_for(first);
                let b = self.listen_for(second);
                match op {
                    "*" => {
                        self.data.insert(name.into(), Result::Done(a * b));
                        a * b
                    },
                    "/" => {
                        self.data.insert(name.into(), Result::Done(a / b));
                        a / b
                    },
                    "+" => {
                        self.data.insert(name.into(), Result::Done(a + b));
                        a + b
                    },
                    "-" => {
                        self.data.insert(name.into(), Result::Done(a - b));
                        a - b
                    },
                    _ => unreachable!(),
                }
            }
        }
    }
}

#[derive(Hash, Eq, PartialEq, Clone)]
enum Result {
    Done(i64),
    Undone(String),
}

impl Result {
    fn from(token: &str) -> Self {
        match token.parse() {
            Ok(num) => Self::Done(num),
            Err(_) => Self::Undone(token.into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::Monkalc;

    const INPUT: &str = "root: pppw + sjmn
dbpl: 5
cczh: sllz + lgvd
zczc: 2
ptdq: humn - dvpt
dvpt: 3
lfqf: 4
humn: 5
ljgn: 2
sjmn: drzm * dbpl
sllz: 4
pppw: cczh / lfqf
lgvd: ljgn * ptdq
drzm: hmdt - zczc
hmdt: 32
";

    #[test]
    fn call_root() {
        let mut monkeys = Monkalc::from(INPUT);
        let number = monkeys.listen_for("root");
        assert_eq!(number, 152);
    }
}
