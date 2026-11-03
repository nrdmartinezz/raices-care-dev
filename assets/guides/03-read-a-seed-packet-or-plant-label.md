---
id: learn_seed_packets
slug: read-a-seed-packet-or-plant-label
title: Read a seed packet or plant label
status: draft
version: 1
source_accessed_at: 2026-11-02
reviewed_at: null
next_guide_id: learn_start_seeds
---

# Read a seed packet or plant label

A packet or nursery label is the starting instruction sheet for the exact plant you bought. Save its details so you do not have to rely on a general calendar or a common name alone.

## What you will learn
- Identify the plant and variety.
- Find sowing, spacing, and timing instructions.
- Treat maturity figures as estimates rather than guaranteed dates.

## 1. Identify the plant
Record the common name, scientific name if supplied, and cultivar or variety. Take a readable photo of both sides of the packet or label. If its identity is unclear, keep that uncertainty visible instead of assigning a confident species match.

## 2. Find the planting method
Look for instructions to sow directly outdoors, start indoors, or plant a nursery transplant. Use the crop-specific directions. Indoor starting is not automatically the best choice for every plant. [S1]

## 3. Find depth, spacing, and germination instructions
Copy sowing depth, final plant spacing, and any thinning instructions separately. Check whether seeds need light, darkness, or special preparation. Seed-specific instructions take priority over generic rules. [S1][S2]

For nursery plants, record mature size and placement instructions if provided. Do not interpret seed sowing depth as the planting depth for a purchased tree, bulb, or transplant.

## 4. Read timing carefully
Find the recommended planting season and days to maturity or harvest. Check whether the supplier counts from sowing or transplanting; if it is unclear, mark the basis unknown rather than inventing a harvest date. Weather and regional growing conditions can change actual timing. [S3][S4]

If the packet says “before last frost,” keep that as a relative instruction until an appropriate regional frost reference is available. Do not convert it into one nationwide date.

## 5. Compare the label with your growing space
Compare the plant's light, spacing, and growing requirements with your location. If your space does not match, choose another location or plant rather than hiding the mismatch.

## Try it in Raíces
Save a label photo and manually confirm the important details. Automatic text extraction, if added later, should produce suggestions that the user reviews—not automatically published care guidance.

## Completion checklist
- [ ] I saved the plant and variety name.
- [ ] I know the recommended planting method.
- [ ] I recorded depth and spacing separately.
- [ ] I know whether maturity timing has a clear starting point.
- [ ] I marked missing information as unknown.

## Quick check
Question: Does “70 days” always mean 70 days after you buy the packet?
Answer: No. Establish what the supplier counts from, and treat the result as an estimate. [S3][S4]

## Implementation notes
Suggested fields: supplier, label_photo_key, scientific_name_raw, cultivar_raw, planting_method, sowing_depth_mm, spacing_mm, germination_days_min/max, maturity_days_min/max, maturity_basis (sowing/transplanting/unknown), relative_timing_text, instructions_raw. Preserve original units/text alongside normalized measurements. Flag disagreements with the catalog for review; do not overwrite the shared guide based on one user's label.

## Sources
[S1] University of Minnesota Extension — Starting seeds indoors: https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/starting-seeds-indoors
[S2] Oregon State University Extension — Growing vegetables in Central Oregon: https://extension.oregonstate.edu/catalog/pub/em-9128-growing-vegetables-central-oregon
[S3] Oregon State University Extension — Succession Planting: https://extension.oregonstate.edu/imported-publication/succession-planting
[S4] Oregon State University Extension — Growing Your Own: https://extension.oregonstate.edu/catalog/em-9027-growing-your-own

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
