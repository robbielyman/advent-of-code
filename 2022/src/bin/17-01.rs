use std::{collections::HashSet, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("17.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let count = height_after(input.trim_end_matches('\n'), 2022);
    println!("{}", count);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
struct Point {
    x: u32,
    y: u32,
}

#[derive(Clone, Copy, Debug)]
struct Block {
    point: Point,
    shape: Shape,
}

fn height_after(input: &str, num: usize) -> u32 {
    let mut cycle = input.trim_end_matches('\n')
        .chars()
        .cycle();
    let mut stack = HashSet::new();
    let mut max_height = 0;
    [Shape::Horiz, Shape::Plus, Shape::Ell, Shape::Vert, Shape::Square]
        .iter()
        .cycle()
        .take(num)
        .for_each(|&shape| {
            let mut block = Block {
                point: Point {
                    x: 2,
                    y: max_height + 3,
                },
                shape
            };
            loop {
                let ch = cycle.next().unwrap();
                let mut clone = block;
                match ch {
                    '<' => if clone.point.x > 0 { clone.point.x -= 1; },
                    '>' => {
                        clone.point.x += 1;
                        match clone.shape {
                            Shape::Horiz => clone.point.x = clone.point.x.min(3),
                            Shape::Plus => clone.point.x = clone.point.x.min(4),
                            Shape::Ell => clone.point.x = clone.point.x.min(4),
                            Shape::Vert => clone.point.x = clone.point.x.min(6),
                            Shape::Square => clone.point.x = clone.point.x.min(5),
                        };
                    },
                    _ => unreachable!(),
                };
                if !overlap(clone, &stack) { block = clone; }
                if block.point.y == 0 { break;}
                let mut clone = block;
                clone.point.y -= 1;
                if overlap(clone, &stack) { break; } else { block = clone; }
            }
            push(block, &mut stack);

            let height = match block.shape {
                Shape::Horiz => 1,
                Shape::Plus => 3,
                Shape::Ell => 3,
                Shape::Vert => 4,
                Shape::Square => 2,
            };
            max_height = max_height.max(block.point.y + height);
        });
    max_height
}

fn push(block: Block, others: &mut HashSet<Point>) {
    let horiz = &[(0, 0), (1, 0), (2, 0), (3, 0)];
    let plus = &[(1, 0), (0, 1), (1, 1), (2, 1), (1,2)];
    let ell = &[(2, 2), (2, 1), (0, 0), (1, 0), (2, 0)];
    let vert = &[(0, 0), (0, 1), (0, 2), (0, 3)];
    let square = &[(0, 0), (1, 0), (0, 1), (1, 1)];
    match block.shape {
        Shape::Horiz => horiz.into_iter(),
        Shape::Plus => plus.into_iter(),
        Shape::Ell => ell.into_iter(),
        Shape::Square => square.into_iter(),
        Shape::Vert => vert.into_iter(),
    }.for_each(|(i,j)| {
        let point = Point { x: block.point.x + i, y: block.point.y + j};
        others.insert(point);
    });
}

fn overlap(block: Block, others: &HashSet<Point>) -> bool {
    let horiz = &[(0, 0), (1, 0), (2, 0), (3, 0)];
    let plus = &[(1, 0), (0, 1), (1, 1), (2, 1), (1,2)];
    let ell = &[(2, 2), (2, 1), (0, 0), (1, 0), (2, 0)];
    let vert = &[(0, 0), (0, 1), (0, 2), (0, 3)];
    let square = &[(0, 0), (1, 0), (0, 1), (1, 1)];
    match block.shape {
        Shape::Horiz => horiz.into_iter(),
        Shape::Plus => plus.into_iter(),
        Shape::Ell => ell.into_iter(),
        Shape::Square => square.into_iter(),
        Shape::Vert => vert.into_iter(),
    }.any(|(i,j)| {
        let point =  Point { x: block.point.x + i, y: block.point.y + j};
        others.contains(&point)
    })
}

#[derive(Clone, Copy, Debug)]
enum Shape {
    Horiz,
    Plus,
    Ell,
    Vert,
    Square,
}

#[cfg(test)]
mod tests {
    use crate::height_after;

    const INPUT: &str = ">>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>
";

    #[test]
    fn height_after_2022() {
        let height = height_after(INPUT, 2022);
        assert_eq!(height, 3068);
    }
}
