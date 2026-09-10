# Architecture and Product Decisions

This file records decisions that should not be silently reversed during implementation.

## D001 — Review is the primary application

Decision: The app is Review-first. There is no conventional dashboard/product hierarchy.

Reason: The product's value is active repertoire recall, not study management.

Implication: Studies/openings are lightweight selectors that constrain Review.

## D002 — Local-first Review

Decision: The critical Review loop never requires the network.

Reason: The user must be able to play at thought speed and offline.

Implication: Local chess validation, repertoire lookup, and SRS updates happen locally.

## D003 — PGN is an input format, not the domain model

Decision: Normalize PGN into Study/Chapter/PositionNode/RepertoireDecision structures.

Reason: Future Lichess import and other sources must converge on one model.

## D004 — Study and opening are different concepts

Decision: A Study is a source/content container. An Opening is a cross-study classification/filter.

Reason: Users may want to review one opening across many studies.

## D005 — Engine is advisory, not the Review judge

Decision: Review correctness is repertoire-based.

Reason: The purpose is remembering the user's preparation, including how to punish opponent mistakes.

## D006 — One-time import analysis may warn about user-side aberrations

Decision: A future import-time engine pass may identify severe user-side evaluation collapses.

Rules: warn only; never block import; do not treat opponent inaccuracies as repertoire defects.

## D007 — Learned does not mean forgotten forever

Decision: Auto-traversed/non-due decisions remain scheduled and can become due again after long intervals.

Reason: Long-term retention requires eventual retrieval practice.

## D008 — No mandatory session completion

Decision: Review has no end-of-session page.

Reason: Artificial session boundaries add product weight without improving the core interaction.

## D009 — Future sync covers both studies and SRS state

Decision: Cloud synchronization should eventually cover both repertoire content and review state.

Reason: Both are small enough and both are required for a coherent cross-device experience.

## D010 — Reference repositories

Decision: Use `ZackMurry/chessrs` and `ArneVogel/listudy` as explicit implementation references.

Links:

- https://github.com/ZackMurry/chessrs
- https://github.com/ArneVogel/listudy

Reason: They provide relevant prior art for chess SRS and study/tree training behaviour.

## D011 — No premature feature expansion

Decision: New features need a product justification tied to repertoire retention/review.

Reason: The product's differentiation depends on focus and speed.
