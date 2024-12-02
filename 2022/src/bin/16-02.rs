use std::{collections::HashSet, fs::File, io::Read, path::Path, time::Instant};

fn main() {
    let path = Path::new("16.txt");
    let mut file = File::open(path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let now = Instant::now();
    let (graph, start_loc) = parse(&input);
    let score = solve(&graph, start_loc);
    println!("{}", score);
    println!("time elapsed: {}ms", now.elapsed().as_millis());
}

struct Node {
    children: Vec<usize>,
    flow_rate: u32,
}

struct BFSIter<'a> {
    graph: &'a Graph,
    state: HashSet<usize>,
    stage: usize,
    done: bool,
}

impl<'a> BFSIter<'a> {
    fn starting_at(graph: &'a Graph, idx: usize) -> Self {
        let mut state = HashSet::new();
        state.insert(idx);
        Self { graph, state, stage: 0, done: false }
    }
}

impl<'a> Iterator for BFSIter<'a> {
    type Item = Vec<(usize, usize)>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.done { return None; }
        let s = self.stage;
        self.stage += 1;
        if s == 0 { return Some(self.state.iter().copied().map(|item| (item, s) ).collect()); }
        let mut new_state = self.state.clone();
        let ret: Vec<_> = self.state.iter()
            .flat_map(|i| {
                self.graph[*i].children.iter().copied()
            })
            .filter(|i| new_state.insert(*i))
            .map(|i| (i, s))
            .collect();
        self.state = new_state;
        if ret.len() > 0 { Some(ret) } else { self.done = true; None }
    }
}

fn distances(graph: &Graph) -> Vec<Vec<usize>> {
    (0..graph.len())
        .map(|idx| {
            let mut res: Vec<_> = BFSIter::starting_at(graph, idx).flatten().collect();
            res.sort_by_key(|(idx, _)| *idx);
            res.into_iter().map(|(_, distance)| distance)
                .collect()
        })
        .collect()
}

type Graph = Vec<Node>;

fn parse(input: &str) -> (Vec<Node>, usize) {
    let mut names = Vec::new();
    let pre_graph: Vec<_> = input
        .lines()
        .map(|line| {
            let relevant: Vec<_> = line
                .split_whitespace()
                .enumerate()
                .filter(|(n, _)| *n == 1 || *n == 4 || *n >= 9)
                .map(|(_, token)| token)
                .collect();
            names.push(relevant[0]);
            let flow_rate = relevant[1]
                .trim_start_matches("rate=")
                .trim_end_matches(";")
                .parse().unwrap();
            (flow_rate, relevant[2..].to_vec())
        })
        .collect();
    let idx = names.iter().enumerate().filter(|(_, name)| *name == &"AA").nth(0).unwrap().0;
    let graph = pre_graph.into_iter()
        .map(|(flow_rate, strings)| {
            let children = strings.into_iter()
                .map(|string| {
                    let matcher = string.trim_end_matches(",");
                    names.iter().enumerate().filter(|(_, name)| *name == &matcher).nth(0).unwrap().0
                })
                .collect();
            Node { children, flow_rate }
        })
        .collect();
    (graph, idx)
}

#[derive(Clone, Debug)]
struct PartialSolution {
    data: HashSet<usize>,
    score: usize,
    remaining: [usize; 2],
    current: [usize; 2],
}

fn solve(graph: &Graph, start_loc: usize) -> usize {
    let distances = distances(graph);
    let vec: Vec<_> = graph
        .iter()
        .enumerate()
        .filter_map(|(i, node)| {
            if node.flow_rate == 0 {
                None
            } else {
                Some((i, node.flow_rate))
            }
        })
        .collect();
    let mut unfinished = vec![PartialSolution {
        data: HashSet::new(),
        score: 0,
        remaining: [26, 26],
        current: [start_loc, start_loc],
    }];
    let mut best = 0;
    while !unfinished.is_empty() {
        for i in 0..2 {
            if unfinished.is_empty() { break; }
            unfinished = unfinished.iter()
                .flat_map(|partial| {
                    vec.iter()
                        .filter_map(|(idx, flow_amt)| {
                            if partial.data.contains(idx) { return None; }
                            let distance = distances[partial.current[i]][*idx] + 1;
                            if distance > partial.remaining[i] { return None; }
                            let mut ret = partial.clone();
                            ret.data.insert(*idx);
                            ret.remaining[i] -= distance;
                            ret.current[i] = *idx;
                            ret.score += ret.remaining[i] * *flow_amt as usize;
                            Some(ret)     
                        })
                })
                .filter(|partial| {
                    let is_incomplete = vec.iter()
                        .any(|(idx, _)| {
                            for i in 0..2 {
                                let distance = distances[partial.current[i]][*idx] + 1;
                                if !partial.data.contains(idx) && distance < partial.remaining[i] { return true; }
                            }
                            false
                        });
                    if !is_incomplete { best = best.max(partial.score); }
                    is_incomplete
                })
                .collect();
        }
    }
    best
}

#[cfg(test)]
mod tests {
    use crate::{parse, solve};

    const INPUT: &str = "Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
Valve BB has flow rate=13; tunnels lead to valves CC, AA
Valve CC has flow rate=2; tunnels lead to valves DD, BB
Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
Valve EE has flow rate=3; tunnels lead to valves FF, DD
Valve FF has flow rate=0; tunnels lead to valves EE, GG
Valve GG has flow rate=0; tunnels lead to valves FF, HH
Valve HH has flow rate=22; tunnel leads to valve GG
Valve II has flow rate=0; tunnels lead to valves AA, JJ
Valve JJ has flow rate=21; tunnel leads to valve II
";

    #[test]
    fn big_graph() {
        let (graph, start) = parse(INPUT);
        let score = solve(&graph, start);
        assert_eq!(score, 1707);
    }
}
