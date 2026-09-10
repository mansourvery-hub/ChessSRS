# Inspiration and Reference Repositories

## Purpose

These repositories are the primary external references for chess-domain implementation ideas. Agents should inspect relevant code before designing new behaviour for PGN study trees, repertoire training, or chess SRS.

They are references, not dependencies and not permission to copy source code.

## 1. ZackMurry/chessrs

GitHub:
https://github.com/ZackMurry/chessrs

Relevant areas:

- chess opening SRS concepts
- review scheduling
- training positions
- repertoire practice
- Lichess-related integration ideas

Use it to understand proven domain behaviour and implementation trade-offs.

## 2. ArneVogel/listudy

GitHub:
https://github.com/ArneVogel/listudy

Relevant areas:

- study/training concepts
- PGN/tree handling
- variations
- repertoire practice
- spaced repetition workflows

Use it to inspect how study trees and training flows are represented/processed.

## Usage rule

Before implementing a related chess-domain feature:

1. inspect the relevant repository code;
2. identify the behaviour/edge case being solved;
3. implement against this project's architecture and contracts;
4. do not blindly copy source code;
5. respect the source repositories' licenses.

## Why two references

They solve overlapping problems from different architectural perspectives. Prefer proven behavioural ideas while keeping this project local-first, Review-first, and deliberately minimal.
