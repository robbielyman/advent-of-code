use std::{fs::File, io::Read, path::Path};

use itertools::Itertools;

fn main() {
    let path = Path::new("08.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let mat = Matrix::from(&input).unwrap();
    println!("{}", best_score(&mat));
}

struct Matrix {
    data: Vec<u32>,
    width: usize,
    height: usize,
}

struct MatrixRow<'a> {
    mat: &'a Matrix,
    start: usize,
    idx: usize,
}

struct MatrixCol<'a> {
    mat: &'a Matrix,
    idx: usize,
}

impl<'a> Iterator for MatrixRow<'a> {
    type Item = &'a u32;

    fn next(&mut self) -> Option<Self::Item> {
        (self.idx < self.mat.width).then(|| {
            let ret = self.mat.data.get(self.start + self.idx).unwrap();
            self.idx += 1;
            ret
        })
    }
}

impl<'a> Iterator for MatrixCol<'a> {
    type Item = &'a u32;

    fn next(&mut self) -> Option<Self::Item> {
        (self.idx < self.mat.data.len()).then(|| {
            let ret = self.mat.data.get(self.idx).unwrap();
            self.idx += self.mat.width;
            ret
        })
    }
}

impl Matrix {
    fn from(string: &str) -> Option<Matrix> {
        let multi_dim = string
            .split_terminator('\n')
            .map(|chunk| {
                chunk
                    .chars()
                    .map(|ch| ch.to_digit(10).unwrap())
                    .collect_vec()
            })
            .collect_vec();
        let height = multi_dim.len();
        let width = multi_dim[0].len();
        Some(Matrix {
            data: multi_dim.into_iter().flatten().collect(),
            width,
            height,
        })
    }

    fn row(&self, which: usize) -> Option<MatrixRow> {
        (which < self.height).then_some(MatrixRow {
            mat: self,
            start: which * self.height,
            idx: 0,
        })
    }

    fn col(&self, which: usize) -> Option<MatrixCol> {
        (which < self.width).then_some(MatrixCol {
            mat: self,
            idx: which,
        })
    }
}

fn score(vec: &Vec<&u32>, idx: usize) -> usize {
    let (before, after) = vec.split_at(idx);
    let height = vec[idx];
    let mut left = 0;
    for tree in before.iter().rev() {
        left += 1;
        if *tree >= height {
            break;
        }
    }
    let mut right = 0;
    for tree in after[1..].iter() {
        right += 1;
        if *tree >= height {
            break;
        }
    }
    left * right
}

fn best_score(mat: &Matrix) -> usize {
    (0..mat.width).map(|i| {
        (0..mat.height).map(|j| {
            score(&mat.col(i).unwrap().collect(), j) * score(&mat.row(j).unwrap().collect(), i)
        })
            .max()
            .unwrap()
    })
        .max()
        .unwrap()
}

#[cfg(test)]
mod tests {
    use crate::{best_score, score, Matrix};

    const INPUT: &str = "30373
25512
65332
33549
35390
";

    #[test]
    fn scoring() {
        let row = vec![&3, &0, &3, &7, &3];
        let results: Vec<_> = (0..5).map(|i| score(&row, i)).collect();
        assert_eq!(results, vec![0, 1, 2, 3, 0]);
    }

    #[test]
    fn best_score_is_eight() {
        let mat = Matrix::from(INPUT).unwrap();
        assert_eq!(best_score(&mat), 8);
    }
}
