---
id: learn_plant_stages
slug: understand-plant-stages
title: Understand plant stages
status: draft
version: 1
source_accessed_at: 2026-11-02
reviewed_at: null
next_guide_id: learn_seed_packets
---

# Understand plant stages

A plant's stage is a description of what you observe, not a countdown. Recording changes helps you ask the right care questions without assuming every plant grows on the same schedule.

## What you will learn
- Recognize germination, seedlings, leafy growth, and reproductive growth.
- Distinguish seed leaves from true leaves.
- Avoid using age alone to decide when to move a plant.

## 1. Germination
Germination is the beginning of growth from a seed. Requirements differ: follow the seed packet for sowing depth, temperature, and whether light or darkness is needed. Do not bury every seed by the same rule. [S1]

## 2. Seedling growth
The first seed leaves are called cotyledons. True leaves develop afterward and resemble the plant's later foliage. Appearance differs among species; do not use a picture of one crop as the identification rule for all crops. [S2]

As seedlings grow, check light, moisture, and available space. True leaves are useful observations, but they do not alone prove a plant is ready for outdoor transplanting. Outdoor conditions and crop-specific guidance still matter. [S1][S2]

## 3. Vegetative growth
Use “vegetative growth” in Raíces to record visible development of leaves, stems, or shoots. Treat this as an observation label, not a rule that prohibits a plant from also flowering.

## 4. Flowering and fruit or seed development
Record visible flowers separately from fruit or seed observations. Do not assume every flower produces a harvest or that a photographed fruit is edible. For edible crops, use the crop's reviewed harvest guidance; seed maturity and eating maturity are not always the same. Oregon State's seed-saving guidance, for example, requires cucumbers to mature beyond their usual eating stage for seed collection. [S3]

## 5. Record establishment and uncertainty separately
A newly planted tree can be mature enough to flower and still be establishing in a new location. In the app, keep “recently planted” separate from flowering observations. If you cannot confidently identify a stage, select “Not sure.” Do not label unexplained leaf loss as dormancy automatically.

## Try it in Raíces
Record one observation and its date: seed sown, sprout seen, true leaves seen, new growth, flowers seen, or fruit/seed development. A photo is optional.

## Completion checklist
- [ ] I can explain seed leaves versus true leaves.
- [ ] I know plant age is not a universal transplant rule.
- [ ] I can record observations without forcing one exclusive stage.

## Quick check
Question: Does seeing true leaves mean you should immediately move a plant outside?
Answer: No. Plant readiness and outdoor conditions must also be suitable. [S1][S2]

## Implementation notes
Use separate observations rather than an exclusive linear state machine. Proposed observation keys: seed_sown, germination_observed, true_leaves_observed, new_growth_observed, flowering_observed, fruit_seed_observed. Store observed_at and observer confidence. Keep establishment_status separate. Dormancy requires supported species context or user selection; never infer death or dormancy solely from lack of logged activity.

## Sources
[S1] University of Minnesota Extension — Starting seeds indoors: https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/starting-seeds-indoors
[S2] Oregon State University Extension — Growing vegetables in Central Oregon: https://extension.oregonstate.edu/catalog/pub/em-9128-growing-vegetables-central-oregon
[S3] Oregon State University Extension — Collecting and storing seeds from your garden: https://extension.oregonstate.edu/gardening/techniques/collecting-storing-seeds-your-garden

## Cursor implementation contract
- This file contains original draft editorial copy, not a production-approved horticultural dataset.
- Import the learner-facing sections as a guide; keep implementation notes out of the learner interface.
- Preserve stable guide IDs, section order, source links, and revision history.
- Do not invent crop-specific temperatures, fertilizer doses, planting dates, toxicity statements, or readiness thresholds.
- Publishing a lesson must not automatically change a user's care plan or create reminders.
- Localize display units; retain canonical units in structured care records.
- Add a report-feedback action containing guide ID and version, not private notes.
- Require editorial review before changing status from draft to published.

## Shared content fields
Use: id, slug, title, summary, learning_objectives, audience, sections, checklist, knowledge_check, next_guide_id, source_links, status, version, reviewed_at.
`reviewed_at` is null until a human editor completes review. Source access date is not editorial review.
