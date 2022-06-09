# Auto-Gnuplot
This project is aimed at helping generate Makefile for multiple Gnuplot scripts. All the script with names ended with `.gnu` in `src` directory are regarded as scripts to run. Their output will all be redirected to the `output` directory.

## Requirements

This script MUST be run with `/bin/bash`, which is available in most popular Linux distributions nowadays.

However, you don't mean to switch current shell to that. The first line of all scripts here prompts the terminal to use the correct Bash shell.

If not, make it manually by 

```shell
$ bash gen-Makefile.sh
```

The tool `gnuplot` must be installed in `PATH`. So it is with `pdfcrop` if figures are wished to be drawn in PDF format, which is useful for academic writings.

## Usage

First, git clone this repository, and `cd` in. (Hint: The directory name `auto-gnuplot` can be renamed to whatever you want.)

```shell
$ git clone https://github.com/shao-xy/auto-gnuplot.git
$ cd auto-gnuplot
```

Then, put your Gnuplot scripts into the `src` directory in any way, with or without tree hierarchy.

Next step is the most important. Hint lines have to be added to EVERY script inside `src` directory.

In the beginning of each file, write a few lines as below:

```gnuplot
# input: file1
# input: file2
# output: file3
```

These lines are omitted by Gnuplot, but visible to `gen-Makefile.sh`. The latter Bash script reads these lines to generate the `Makefile`, which later helps automatically draw these figures if any data are modified.

If no hint lines are given, `gen-Makefile.sh` read lines from the script itself, and tries to find lines like `set output xxx`. This works with simple path strings, but is risky in case Gnuplot supports variables or other methods to create a path string.

There might be many input files in different hint lines, or none at all, but no more than one output is supported.

## Explanation of input/output paths in hint lines

Both absolute and relative paths are supported. For relative paths, input and output lines behave differently.

In terms of output lines, relative paths always start from a similar same path in the `output` directory. The prefix `src/` is replaced with `output/`, and figures are drawn starting in the same parent path. For example, the next line in `src/foo/bar.gnu` refers to `output/foo/bar.png`:

```gnuplot
# output: bar.png
```
Since `bar.png` is a relative path, and its source file is `foo/bar.gnu`, this tool copies the hierarchy of `foo/` under `src/` to `output/`, and then draws `bar.png` there.

In terms of input lines, relative paths means the current directory of the Gnuplot script. For example, files in `src` directory is organized as below:

```txt
+ src/
- ---- + foo/
       - ---- * bar.gnu
       - ---- + data/
              - ---- * bar.txt
```

And the hint lines in `src/foo/bar.gnu` can be like this:

```gnuplot
# input: data/bar.txt
```

# Collaboration and PRs are always welcome here! Enjoy!
