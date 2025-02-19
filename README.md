# Complete Compiler Project

This project implements a complete compiler for an extended programming language, building upon the previous practice. The compiler supports boolean expressions, conditional statements, iterative control structures, and generates intermediate code in **Three-Address Code (C3A)** format following the provided specification.

## Features

- **Parsing and Lexical Analysis** using **Bison** and **Flex**.
- **Symbol Table Management** with support for user-defined variables and type handling.
- **Intermediate Code Generation** with backpatching for control flow.
- **Conditional Statements**: 
  - `if-then`
  - `if-then-else`
- **Loop Structures**:
  - `while-do`
  - `repeat-do-done`
  - `do-until`
  - `for`

## Compilation Instructions

To compile and run the project, follow these steps:

```bash
# Generate parser and scanner
bison -d parser.y
flex scanner.l

# Compile using Makefile
make

# Run the compiler with an example input file
./calculator prova/prova_nom.txt

# Clean compiled files
make clean
