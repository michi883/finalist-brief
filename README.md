# Finalist Brief

Finalist Brief turns a set of hackathon submissions into an explorable visual field. Judges can view the competition through different lenses, zoom into a submission, and inspect its idea and integration structure.

## Context

Hackathon judges have limited time to understand a diverse set of projects. Submission descriptions, repositories, and demos contain useful information, but comparing them requires repeatedly reconstructing what each project is trying to do and how it works.

Finalist Brief explores a visual way to support that first pass: help judges notice differences, understand project structure, and decide where to spend more attention. Human judges retain responsibility for evaluation and decisions.

The project is being built for the Serverpod hackathon. Its current prototype uses the existing **Humor Genome: Build with Gemma** submission dataset to test the exploration experience.

## Objectives

The current iteration helps a judge answer three questions:

1. **What stands out through this lens?** See how the competition changes when different characteristics become the focus.
2. **What is the underlying shape of this submission?** Understand its actors, inputs, transformations, outputs, and feedback relationships.
3. **How does that shape change through another lens?** Move between the project's idea and its technical integration.

A later objective is to answer **“Why does Finalist Brief believe what it shows?”** by connecting representations to supporting evidence. Evidence drill-down is not implemented in this prototype.

## One information space, two scales

### Competition View

Six submissions appear as dots in a two-dimensional field. Switching lenses animates the dots into a new arrangement, making different relationships visible.

| Lens | Horizontal dimension | Vertical dimension |
|---|---|---|
| Standout | Structural distinctiveness | Evidence inspectability |
| Human Loop | Human-world grounding | Interaction depth |
| System Depth | System orchestration | Creative scope |
| Audience Reality | Audience centrality | Human-world grounding |

Custom axes allow any of these seven dimensions on either axis. Positions are descriptive interpretations, **not judge scores or rankings**. The top-right corner means more of the two selected traits; it does not identify a winner.

### Submission View

Selecting a dot expands it into the project's visual structure. The transition is intended to feel like moving inside the submission. Returning collapses the structure back into its original position in the competition.

Two submission lenses reveal different aspects of the same project:

- **Idea:** the core concept, the people or audiences involved, and the relationships that make the idea work.
- **Integration:** how product surfaces, models, processing steps, external systems, and outputs connect.

A small competition map preserves context, and judges can jump directly between submissions while keeping the active lens.

## The submission determines the topology

**The submission determines the topology. Finalist Brief determines the visual grammar.**

Different projects need different shapes. A creative workbench can form a hub; an audience experiment can branch and merge; a rehearsal tool can form a feedback loop. Every submission should reveal its own structure.

The prototype uses a shared language for humans, product surfaces, AI models, transformations, external systems, observed signals, and artifacts. Directed edges express relationships; dashed edges express iteration. Semantic project data is separate from rendering, so reusable layouts determine positions from relationships and structural hints.

The design test is whether judges perceive meaningful differences across projects and lenses while remaining able to read the shared visual language.

## Current prototype

The desktop-oriented Flutter app includes four competition presets, configurable axes, animated movement, reversible zoom, Idea and Integration representations, and direct project switching.

The six contestants are **Crowdwork Copilot**, **Humor Genome Studio**, **Killjoy**, **LaughLensAI**, **Room Sense Text**, and **Why'd They Laugh?**. The additional `laughlens-platform` entry in the historical dataset is excluded from the visual experience.

The demo is deterministic. Dimension placements and semantic graphs are manually authored from the checked-in submission descriptions and cached analyses. They are explanatory interpretations, not automatically extracted architecture or calibrated measurements. The visual experience loads bundled data and makes no live analysis requests.

Live model analysis, automatic topology extraction, automated judging, finalist ranking, evidence drill-down, and production mobile support are outside the current scope.

The Serverpod backend, cached analyses, and earlier video-generation infrastructure remain available for future work. The visual exploration experience is now the product centerpiece.

## Run the demo

From the repository root:

```sh
serverpod start
```

Open **http://localhost:9998/?demo=1**. The root URL also opens the cached visual experience. Choose a competition lens, select a dot, and switch between Idea and Integration. Use **Competition** or **Esc** to return to the field.

The Flutter launch configuration pins port 9998. An existing session started before that setting may use the port printed in its launch output.

## Development

The app uses Flutter and Serverpod. Representations live in [`finalist_brief_flutter/assets/representations/humor_genome.json`](finalist_brief_flutter/assets/representations/humor_genome.json), with semantic types in `lib/representation/`, shared rendering in `lib/visualization/`, and the exploration screen in `lib/views/`.

Tests cover representation integrity, layouts, animation continuity, lens switching, and competition-context restoration. Run `dart analyze` from the root, `flutter test` in `finalist_brief_flutter`, and `dart test` in `finalist_brief_server`. Server tests use embedded PostgreSQL without Docker.

See [PLAN.md](PLAN.md) for the current build contract and archived video plan, and [AGENTS.md](AGENTS.md) for the development workflow. [INSTRUCTIONS.md](INSTRUCTIONS.md) preserves the original project brief.
