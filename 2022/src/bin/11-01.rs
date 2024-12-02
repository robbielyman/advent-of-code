use std::{fs::File, io::Read, path::Path};

fn main() {
    let path = Path::new("11.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let mut monkeys: Vec<_> = input.split("\n\n").map(|m| { Monkey::from(m).unwrap() }).collect();
    let score = score(&mut monkeys);
    println!("{}", score);
}

#[derive(Debug, PartialEq, Eq)]
struct Monkey {
    items: Vec<usize>,
    operation: Operation,
    divisible_by: usize,
    if_true: usize,
    if_false: usize,
}

#[derive(Debug, PartialEq, Eq)]
enum Operation {
    Mul(Operand),
    Add(Operand),
}

#[derive(Debug, PartialEq, Eq)]
enum Operand {
    Input,
    Num(usize),
}

impl Monkey {
    fn from(input: &str) -> Option<Self> {
        let mut lines = input.lines();
        lines.next()?;
        let (_, starting) = lines.next()?.split_once(':')?;
        let items: Vec<usize> = starting
            .split(&[':', ',', ' '])
            .filter_map(|token| token.parse().ok())
            .collect();
        let mut iter = lines.next()?.split_whitespace().rev().take(2);
        let op = match iter.next()? {
            "old" => Operand::Input,
            s => Operand::Num(s.parse().ok()?),
        };
        let operation = match iter.next()? {
            "+" => Operation::Add(op),
            "*" => Operation::Mul(op),
            _ => return None,
        };
        let divisible_by = lines.next()?.split_whitespace().last()?.parse().ok()?;
        let if_true = lines.next()?.split_whitespace().last()?.parse().ok()?;
        let if_false = lines.next()?.split_whitespace().last()?.parse().ok()?;
        Some(Self {
            items,
            operation,
            divisible_by,
            if_true,
            if_false,
        })
    }
}

fn round(monkeys: &mut Vec<Monkey>) -> Vec<usize> {
    let mut output = Vec::new();
    for idx in 0..monkeys.len() {
        output.push(monkeys[idx].items.len());
        let mut if_true = Vec::new();
        let mut if_false = Vec::new();
        for item in monkeys[idx].items.iter() {
            let new = match monkeys[idx].operation {
                Operation::Mul(Operand::Input) => item * item,
                Operation::Mul(Operand::Num(i)) => item * i,
                Operation::Add(Operand::Input) => item + item,
                Operation::Add(Operand::Num(i)) => item + i,
            };
            let to_throw = new / 3;
            match to_throw % monkeys[idx].divisible_by {
                0 => if_true.push(to_throw),
                _ => if_false.push(to_throw),
            }
        }
        monkeys[idx].items.clear();
        let if_true_idx = monkeys[idx].if_true;
        monkeys[if_true_idx].items.append(&mut if_true);
        let if_false_idx = monkeys[idx].if_false;
        monkeys[if_false_idx].items.append(&mut if_false);
    }
    output
}

fn score(monkeys: &mut Vec<Monkey>) -> usize {
    let mut counts: Vec<usize> = Vec::new();
        for _ in 0..monkeys.len() {
            counts.push(0);
        }
        let monkey_business = (0..20).map(|_| {
            round(monkeys)
        })
            .fold(counts, |score, res| {
                score.iter()
                    .zip(res.iter())
                    .map(|(i, j)| { i + j })
                    .collect()
            });
        let mut most_active = [0, 0];
        for score in monkey_business {
            if score >= most_active[0] {
                most_active[1] = most_active[0];
                most_active[0] = score;
            } else if score >= most_active[1] {
                    most_active[1] = score;
                }
        }
    most_active[0] * most_active[1]
}

#[cfg(test)]
mod tests {
    use crate::{score, Monkey, Operand, Operation};

    const INPUT: &str = "Monkey 0:
  Starting items: 79, 98
  Operation: new = old * 19
  Test: divisible by 23
    If true: throw to monkey 2
    If false: throw to monkey 3

Monkey 1:
  Starting items: 54, 65, 75, 74
  Operation: new = old + 6
  Test: divisible by 19
    If true: throw to monkey 2
    If false: throw to monkey 0

Monkey 2:
  Starting items: 79, 60, 97
  Operation: new = old * old
  Test: divisible by 13
    If true: throw to monkey 1
    If false: throw to monkey 3

Monkey 3:
  Starting items: 74
  Operation: new = old + 3
  Test: divisible by 17
    If true: throw to monkey 0
    If false: throw to monkey 1
";

    #[test]
    fn parse_monkeys_rounds() {
        let mut monkeys: Vec<_> = INPUT
            .split("\n\n")
            .filter_map(|monkey| Monkey::from(monkey))
            .collect();
        assert_eq!(
            monkeys,
            vec![
                Monkey {
                    items: vec![79, 98],
                    operation: Operation::Mul(Operand::Num(19)),
                    divisible_by: 23,
                    if_true: 2,
                    if_false: 3,
                },
                Monkey {
                    items: vec![54, 65, 75, 74],
                    operation: Operation::Add(Operand::Num(6)),
                    divisible_by: 19,
                    if_true: 2,
                    if_false: 0,
                },
                Monkey {
                    items: vec![79, 60, 97],
                    operation: Operation::Mul(Operand::Input),
                    divisible_by: 13,
                    if_true: 1,
                    if_false: 3,
                },
                Monkey {
                    items: vec![74],
                    operation: Operation::Add(Operand::Num(3)),
                    divisible_by: 17,
                    if_true: 0,
                    if_false: 1,
                },
            ]
        );
        assert_eq!(score(&mut monkeys), 10605);
    }
}
