use std::{collections::HashMap, fs::File, io::Read, path::Path};

fn main() {
    let path = Path::new("07.txt");
    let mut file = File::open(&path).expect("file open");
    let mut input = String::new();
    file.read_to_string(&mut input).expect("file read");
    let root = from(&input).unwrap();
    let smallest = smallest_that_works(&root).expect("smallest should exist");
    println!("{}", smallest);
}

enum Node {
    Dir(Vec<String>),
    File(usize),
}

fn smallest_that_works(root: &HashMap<Vec<String>, Node>) -> Option<usize> {
    let Ok(root_size) = size_of(root, &vec!["/".into()]) else {
        return None;
    };
    let root_size_free = 70_000_000 - root_size;
    root.iter()
        .filter_map(|(path, node)| {
            match node {
                Node::File(_) => None,
                Node::Dir(_) => Some(size_of(root, path).ok()?),
            }
        })
        .filter(|size| root_size_free + *size >= 30_000_000)
        .min()
}

fn size_of(root: &HashMap<Vec<String>, Node>, name: &Vec<String>) -> Result<usize, String> {
    let Some(node) = root.get(name) else {
        return Err(format!("{} not found!", name.join("/")));
    };
    match node {
        Node::Dir(d) => Ok(d
                           .iter()
                           .map(|child| {
                               let mut new_name = name.clone();
                               new_name.push(child.clone());
                               size_of(root, &new_name)
                           })
            .collect::<Result<Vec<usize>, String>>()?
            .iter()
            .sum()),
        Node::File(s) => Ok(*s),
    }
}

fn from(string: &str) -> Result<HashMap<Vec<String>, Node>, String> {
    let mut root: HashMap<Vec<String>, Node> = HashMap::new();
    let mut pwd = Vec::new();
    root.insert(vec!["/".to_string()], Node::Dir(Vec::new()));
    for command in string.split('$').skip(1) {
        let tokens: Vec<&str> = command.split_whitespace().collect();
        match tokens[0] {
            "cd" => match tokens[1] {
                ".." => _ = pwd.pop(),
                token => pwd.push(token.into()),
            },
            "ls" => {
                let mut node_children = Vec::new();
                for child in tokens[1..].chunks(2) {
                    let name = child[1].to_string();
                    node_children.push(name.clone());
                    let mut new_name = pwd.clone();
                    new_name.push(name.clone());
                    if let Some(_) = root.insert(new_name, match child[0] {
                        "dir" => Node::Dir(Vec::new()),
                        number => Node::File(number.parse().map_err(|_| "parse failed".to_string())?),
                    }) {
                        return Err("overwriting existing node!".into());
                    }
                }
                if let Some(Node::Dir(node)) = root.get_mut(&pwd) {
                   *node = node_children;
                } else {
                    return Err(format!("unable to get node at {}", pwd.join("/")));
                }
            }
            _ => return Err("bad command!".into()),
        }
    }
    Ok(root)
}

#[cfg(test)]
mod tests {
    use crate::{smallest_that_works, from};

    const INPUT: &str = "$ cd /
$ ls
dir a
14848514 b.txt
8504156 c.dat
dir d
$ cd a
$ ls
dir e
29116 f
2557 g
62596 h.lst
$ cd e
$ ls
584 i
$ cd ..
$ cd ..
$ cd d
$ ls
4060174 j
8033020 d.log
5626152 d.ext
7214296 k
";

    #[test]
    fn test_from() {
        let dir = from(INPUT).unwrap();
        let smallest = smallest_that_works(&dir).unwrap();
        assert_eq!(24933642, smallest);
    }
}
