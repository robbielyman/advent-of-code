use std::{collections::HashMap, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("21.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let mut monkeys = Monkalc::from(&input);
    let count = monkeys.call_root();
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

struct Monkalc {
    data: HashMap<String, Result>,
    backout: Vec<Box<dyn Fn(i64) -> i64>>,
}

impl Monkalc {
    fn from(input: &str) -> Self {
        Self {
            data: input.lines()
                .map(|line| {
                    let (name, operation) = line.split_once(": ").unwrap();
                    if name == "humn" {
                        (name.into(), Result::Algebraic(None))
                    } else {
                        (name.into(), Result::from(operation))
                    }
                })
                .collect(),
            backout: Vec::new(),
        }
    }

    fn sound(&mut self, name: &str) {
        let result =  self.data.get(name).unwrap().clone();
        match result {
            Result::Undone(token) => {
                let [first, op, second] = (&token).split_whitespace().collect::<Vec<&str>>()[0..3] else {
                    panic!("bad token {}", token);
                };
                self.sound(first);
                self.sound(second);
                match self.data.get(first).unwrap().clone() {
                    Result::Done(a) => match self.data.get(second).unwrap().clone() {
                        Result::Done(b) => {
                            let result = match op {
                                "*" => a * b,
                                "/" => a / b,
                                "+" => a + b,
                                "-" => a - b,
                                _ => unreachable!(),
                            };
                            self.data.insert(name.into(), Result::Done(result));
                        },
                        Result::Algebraic(_) => {
                            let result: Box<dyn Fn(i64) -> i64> = match op {
                                "*" => Box::new(move |input| input / a), // y = a * x => x = y / a
                                "/" => Box::new(move |input| a / input), // y = a / x => x = a / y
                                "-" => Box::new(move |input| a - input), // y = a - x => x = a - y
                                "+" => Box::new(move |input| input - a), // y = a + x => x = y - a
                                _ => unreachable!(),
                            };
                            let idx = self.backout.len();
                            self.backout.push(result);
                            self.data.insert(name.into(), Result::Algebraic(Some((second.into(), idx))));
                        }
                        Result::Undone(_) => unreachable!(),
                    },
                    Result::Algebraic(_) => match self.data.get(second).unwrap().clone() {
                        Result::Done(b) => {
                            let result: Box<dyn Fn(i64) -> i64> = match op {
                                "*" => Box::new(move |input| input / b), // y = x * b => x = y / b
                                "/" => Box::new(move |input| b * input), // y = x / b => x = b * y
                                "-" => Box::new(move |input| b + input), // y = x - b => x = b + y
                                "+" => Box::new(move |input| input - b), // y = x + b => x = y - b
                                _ => unreachable!(),
                            };
                            let idx = self.backout.len();
                            self.backout.push(result);
                            self.data.insert(name.into(), Result::Algebraic(Some((first.into(), idx))));
                        },
                        Result::Algebraic(_) => {
                            panic!("oh no!");
                        },
                        Result::Undone(_) => unreachable!(),
                    },
                    Result::Undone(_) => unreachable!(),
                };
            }
            _ => {}
        }
    }

    fn call_root(&mut self) -> i64 {
        let Result::Undone(reference) = self.data.get("root").unwrap().clone() else {
            panic!("what??");
        };
        let [first, _, second] = reference.split_whitespace().collect::<Vec<&str>>()[0..3] else {
            panic!("bad token!");
        };

        self.sound(first);
        self.sound(second);
        match self.data.get(first).unwrap().clone() {
            Result::Done(mut num) => {
                let Result::Algebraic(mut maybe_op) = self.data.get(second).unwrap().clone() else {
                    unreachable!();
                };
                while maybe_op.is_some() {
                    let op = maybe_op.unwrap();
                    num = self.backout[op.1](num);
                    maybe_op = match self.data.get(&op.0).unwrap() {
                        Result::Algebraic(m) => m.clone(),
                        _ => unreachable!(),
                    };
                }
                num
            },
            Result::Algebraic(mut maybe_op) => {
                let Result::Done(mut num) = self.data.get(second).unwrap() else {
                    unreachable!();
                };
                while maybe_op.is_some() {
                    let op = maybe_op.unwrap();
                    num = self.backout[op.1](num);
                    maybe_op = match self.data.get(&op.0).unwrap() {
                        Result::Algebraic(m) => m.clone(),
                        _ => unreachable!(),
                    };
                }
                num
            },
            Result::Undone(_) => unreachable!(),
        }
    }
}

#[derive(Hash, Eq, PartialEq, Clone, Debug)]
enum Result {
    Done(i64),
    Undone(String),
    Algebraic(Option<(String, usize)>),
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
        let number = monkeys.call_root();
        assert_eq!(number, 301);
    }
}
