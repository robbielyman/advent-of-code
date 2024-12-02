use std::fs::File;
use std::io::Read;
use std::path::Path;

fn main() {
    let path = Path::new("02.txt");
    let mut file = match File::open(&path) {
        Err(why) => panic!("couldn't open {}: {}", path.display(), why),
        Ok(file) => file,
    };
    let mut input = String::new();
    match file.read_to_string(&mut input) {
        Err(why) => panic!("unable to read {}: {}", path.display(), why),
        Ok(_) => {}
    };
    println!("{}", score(input));
}

#[derive(Copy, Clone)]
enum Shape {
    Rock,
    Paper,
    Scissors,
}

impl Shape {
    fn from_char(c: char) -> Option<Shape> {
        match c {
            'A' => Some(Shape::Rock),
            'B' => Some(Shape::Paper),
            'C' => Some(Shape::Scissors),
            _ => None,
        }
    }

    fn from_them_and_outcome(them: Shape, outcome: MatchOutcome) -> Shape {
        match them {
            Shape::Rock => match outcome {
                MatchOutcome::Win => Shape::Paper,
                MatchOutcome::Loss => Shape::Scissors,
                MatchOutcome::Tie => Shape::Rock,
            },
            Shape::Paper => match outcome {
                MatchOutcome::Win => Shape::Scissors,
                MatchOutcome::Loss => Shape::Rock,
                MatchOutcome::Tie => Shape::Paper,
            },
            Shape::Scissors => match outcome {
                MatchOutcome::Win => Shape::Rock,
                MatchOutcome::Loss => Shape::Paper,
                MatchOutcome::Tie => Shape::Scissors,
            },
        }
    }
}

#[derive(Copy, Clone)]
enum MatchOutcome {
    Win,
    Loss,
    Tie,
}

impl MatchOutcome {
    fn from_char(c: char) -> Option<MatchOutcome> {
        match c {
            'X' => Some(MatchOutcome::Loss),
            'Y' => Some(MatchOutcome::Tie),
            'Z' => Some(MatchOutcome::Win),
            _ => None,
        }
    }
}

fn score(string: String) -> usize {
    let mut score: usize = 0;
    for round in string.split_terminator('\n') {
        let them = match round.chars().nth(0) {
            None => panic!("string too short!"),
            Some(c) => c,
        };
        let us = match round.chars().nth(2) {
            None => panic!("string too short!"),
            Some(c) => c,
        };
        let a = match Shape::from_char(them) {
            None => panic!("bad input {}", them),
            Some(a) => a,
        };
        let outcome = match MatchOutcome::from_char(us) {
            None => panic!("bad input {}", us),
            Some(b) => b,
        };
        let b = Shape::from_them_and_outcome(a, outcome);
        score += match b {
            Shape::Rock => 1,
            Shape::Paper => 2,
            Shape::Scissors => 3,
        };
        score += match outcome {
            MatchOutcome::Win => 6,
            MatchOutcome::Tie => 3,
            MatchOutcome::Loss => 0,
        };
    }
    score
}

#[cfg(test)]
mod tests {
    use crate::score;

    const INPUT: &str = "A Y
B X
C Z
";
    #[test]
    fn scoring() {
        let score = score(INPUT.to_string());
        assert_eq!(score, 12);
    }
}
