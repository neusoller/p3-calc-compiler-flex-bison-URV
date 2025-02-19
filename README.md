# Complete Compiler Project
This project implements a complete compiler for an extended programming language, building upon the previous practice. The compiler supports boolean expressions, conditional statements, iterative control structures, and generates intermediate code in Three-Address Code (C3A) format following the provided specification.

# Features
· Parsing and Lexical Analysis using Bison and Flex.
· Symbol Table Management with support for user-defined variables and type handling.
· Intermediate Code Generation with backpatching for control flow.
· Support for Conditional Statements (if-then, if-then-else) and Loop Structures (while-do, repeat-do-done, do-until, for).

# Compilation Instructions
bison -d parser.y
flex scanner.l
make
./calculator prova/prova_nom.txt
make clean
