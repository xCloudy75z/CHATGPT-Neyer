# Neyer Pre-Test Planner and Reliability Correction — Approved Design

**Date:** 7 September 2026  
**Status:** Approved by the user  
**Supported MATLAB:** R2022b  
**Primary deliverable:** One standalone MATLAB Live Script (`.mlx`)

## 1. Purpose

The tool supports destructive tests of independently printed articles at different physical gaps. Each article produces one result: **Interaction** or **No interaction**.

The finished tool must help the user:

1. estimate how many new articles to prepare before entering the laboratory;
2. request only gaps that the physical setup can build;
3. record the requested gap, repeated measurements of the actual gap, and the physical result;
4. estimate the middle gap and overall variation;
5. calculate a cautious operating gap for a chosen reliability and confidence;
6. explain whether the evidence is sufficient and whether reserves are needed; and
7. save and reopen the study without silently replacing earlier data.

The tool must not turn an estimate into a guarantee, call the 50/50 middle gap “99% reliable,” or present an impossible gap as usable.

## 2. Evidence and decision rules

Every important statement is classified as one of the following:

| Label | Meaning |
|---|---|
| User fact | Physical information confirmed by the user |
| Published rule | A statement supported by the Neyer paper or another named primary source |
| Executed test | A result produced by MATLAB |
| Simulation result | A result produced by a recorded virtual study |
| Assumption | Information not yet physically confirmed |
| Recommendation | A usability or safety choice |

Priority is: confirmed physical facts, published method, executed evidence, and then clearly labelled assumptions. Reference-table reproduction is a regression check; it is not proof that a modification is statistically correct.

When evidence conflicts, the affected claim stops. The tool does not silently relax reliability, confidence, accuracy, physical bounds, or response direction.

## 3. Plain-language meanings

| Tool wording | Meaning |
|---|---|
| Middle gap | The estimated gap where Interaction and No interaction are each about 50% likely |
| Overall variation | How much the entire tested process varies, including articles, materials, spacer construction, assembly, measurement, and other uncontrolled differences |
| Reliability | The minimum fraction of similar articles expected to produce the selected result |
| Confidence | How strongly the collected evidence supports that reliability statement |
| Best estimate | The centre prediction from the fitted response curve |
| Confidence-protected result | The cautious value obtained from the appropriate one-sided confidence boundary |
| Reachable gap | A gap that the physical setup can actually construct |

“Transition width” is not shown on the normal input screen. If the technical word sigma is shown in detailed results, it is immediately explained as the estimated overall variation.

## 4. Default physical direction

The gap application uses this default direction:

> Increasing the gap makes Interaction less likely.

Therefore:

| Goal | Operating instruction |
|---|---|
| Reliable Interaction | Use the stated gap or smaller |
| Reliable No interaction | Use the stated gap or larger |

The opposite direction may be available as an advanced option, but it must never be selected silently.

## 5. Pre-Test Planner workflows

The planner begins with **How would you like to plan?**

### 5.1 Requirements-first mode

The user enters:

- required outcome: Interaction or No interaction;
- reliability from 10% to 99.9%;
- confidence from 10% to 99.9%;
- required gap accuracy, such as ±0.05 mm or ±0.10 mm;
- a smaller gap where Interaction is expected almost every time;
- a larger gap where No interaction is expected almost every time;
- permitted minimum and maximum gaps; and
- the physical reachable-gap description.

The planner returns:

- main-study quantity;
- reserve group 1;
- reserve group 2;
- total articles to prepare;
- assumptions used;
- whether the request appears achievable; and
- alternatives when it does not appear achievable.

### 5.2 Available-articles-first mode

The user enters the total number of articles available plus the same physical and accuracy information. The planner shows expected combinations of reliability and confidence that the quantity may support.

This is a pre-test expectation, not a final claim. Final confidence and reliability depend on the real gap locations and outcomes.

The interface must allow either of these questions:

- “With this reliability, what confidence may be achievable?”
- “With this confidence, what reliability may be achievable?”

It must not pretend that an article count alone uniquely determines both reliability and confidence.

## 6. Confidence below 50%

The full approved input range is 10% to 99.9%, but the interface explains:

- 10%–49.9%: exploratory only, not a conservative reliability claim;
- 50%: centre estimate with no safety margin; and
- above 50%: conservative confidence protection.

The recommended default confidence is 95%. The selected outcome has no silent default; the user must choose Interaction or No interaction.

## 7. First study with no previous results

“No, this is my first study” is the default answer to the previous-information question.

The user supplies the smaller almost-always-Interaction gap and the larger almost-always-No-interaction gap. The planner interprets “almost every time” as at least 95%, not as 100%.

The interval supplies a cautious starting estimate of how gradually the outcome may change. Virtual validation covers more sudden, expected, and more gradual curves. The assumption is shown to the user and is replaced by real estimates once test data exist.

If the uncertainty is too broad to support one trustworthy full-study quantity, the planner suggests a smaller discovery study and states that it does not guarantee the final requested confidence and reliability.

## 8. Quantity calculation and validation

The existing hidden `0.5 × sigma` precision target is not retained as an unexplained universal rule.

The published large-sample Neyer/Banerjee relationships provide only a starting estimate. The design acknowledges the Neyer practical correction that the spread variance behaves more like `sigma² / (0.507 × (N − 15))` for larger N, and the advice to add articles when the starting spread or middle range is uncertain.

The production planning rule is calibrated by recorded synthetic studies of the actual application workflow. The user-facing planner must respond promptly; it does not launch an unannounced hour-long study on every click. It uses the validated rule and labels the result as a pre-test estimate.

For candidate quantities, the virtual study repeats:

```text
Known true curve → Neyer sequence → fitted result → compare with known truth
```

A quantity passes only when the recorded validation shows:

1. a usable curve is obtained at the agreed success rate;
2. the middle-gap confidence range behaves as claimed;
3. the selected reliability statement uses the correct cautious boundary;
4. the selected gap is physically reachable after safe rounding; and
5. the exact planned/reserve stopping procedure does not weaken the claim.

The planned-study success requirement is at least 95%, or the requested confidence when it is higher than 95%. Low confidence never permits a high chance of failing to obtain a usable curve.

If validation does not support the requested combination, the suggestion order is:

1. increase the article quantity;
2. add or increase reserves;
3. improve the physical gap capability;
4. accept wider gap accuracy; and
5. reduce confidence or reliability only after explicit user approval.

## 9. Main and reserve quantities

The planner reports three pre-declared groups:

| Group | Purpose |
|---|---|
| Main study | Expected conditions |
| Reserve group 1 | Moderately different but plausible conditions |
| Reserve group 2 | Difficult but still plausible conditions |

The app checks only at the declared checkpoints. It does not repeatedly inspect the result after every extra article unless that exact procedure has been simulated and approved.

At each checkpoint, the app checks:

- both outcomes and sufficient overlap for a valid fit;
- a finite middle and positive overall variation;
- a finite confidence range for the middle;
- whether the requested middle-gap accuracy is achieved;
- whether the target reliability/confidence boundary is established inside the permitted range; and
- whether a safely rounded reachable setting exists.

Reserves are never used automatically. The app explains what is missing and asks the user before continuing. An incomplete study is not described as a failed physical test.

## 10. Physical reachable gaps

The planner offers three physical descriptions:

1. **Regular increments** — only when every multiple of the increment can genuinely be built.
2. **Spacer and foil combinations** — recommended for the user’s setup.
3. **Confirmed reachable-gap list** — direct entry of known buildable gaps.

The current physical information is provisional:

- aluminium foil nominally about 0.015 mm;
- printed spacers nominally 0.50, 1.00, and 2.00 mm;
- example measurements include 0.50 mm, approximately 1.10 mm, approximately 2.09 mm, and 3.67 mm for one combined setup;
- printed spacer thickness varies; and
- every destructive test uses a newly constructed setup.

These values remain marked **unconfirmed** until the user completes the planned physical measurements.

The algorithm chooses the nearest **different, reachable, and useful** setting. It must not loop indefinitely on the same rounded setting.

Validation compares physical capabilities including 0.05, 0.10, 0.15, and 0.50 mm, plus irregular reachable lists.

## 11. Requested and measured gaps

Requested build instructions always display two decimal places.

For each new setup, the user enters four or five measurements of that unchanged setup. The app:

- preserves all readings;
- displays their average;
- uses the average measured gap in the Neyer fit;
- keeps the requested gap separately;
- records the reading range as measurement-repeatability information; and
- never counts repeated measurements as separate test articles.

If the measured average differs from the requested setting, the physical result belongs to the measured average.

## 12. Safe rounding and bounds

For a confidence-protected Interaction limit, rounding moves to a reachable gap at or below the mathematical value. For a confidence-protected No-interaction limit, rounding moves to a reachable gap at or above the mathematical value.

If a confidence boundary lies outside 0–10 mm or the configured permitted range, the app reports that it was not established. It never displays a negative gap or a value above the maximum as a usable setting.

## 13. Confirmed V1.9 reliability defect

The existing “probability at a gap” calculation finds the correct centre prediction but searches the wrong side of the profile when calculating the claimed confidence-protected minimum.

Executed MATLAB evidence includes:

| Gap | Best Interaction estimate | Current claimed minimum |
|---:|---:|---:|
| 3.00 mm | 93.87% | 99.90% |
| 4.61 mm | 49.92% | 76.57% |
| 5.00 mm | 35.32% | 61.87% |

At more extreme gaps, the same defect can collapse to the artificial `0.0001%` floor. The missing regression test allowed all six existing reliability tests to pass because they checked only centre probabilities and target gaps, not the one-sided probability floor.

Required correction procedure:

1. add tests that reproduce both incorrect directions;
2. verify the new tests fail before production changes;
3. correct only the root search direction and related naming/explanations;
4. test Interaction and No interaction at low, middle, and high gaps;
5. verify the confidence-protected probability never exceeds the centre prediction;
6. validate its repeated-study confidence behaviour; and
7. rebuild and retest the standalone `.mlx`.

## 14. Separate fixed-gap qualification

The current build does not add the optional zero-failure qualification planner.

The Neyer curve study and a later fixed-gap zero-failure demonstration remain separate. The specific MIL-DTL-23659F number 298 must never be presented as a universal Neyer sample quantity. The general conservative zero-failure R99/C95 calculation rounds to 299.

## 15. Saving and continuation

The planner saves a human-readable JSON plan chosen by the user. The interface displays the full destination before saving and prevents silent replacement.

The saved plan contains:

- version and date;
- planning mode;
- selected outcome, reliability, confidence, and accuracy;
- physical expectations and permitted bounds;
- reachable-gap definition;
- previous-information choice and assumptions;
- main, reserve 1, reserve 2, and total quantities;
- validation basis and limitations; and
- current checkpoint status.

“Run a Test” can load this plan after MATLAB is closed and reopened. Results remain linked to the plan. Generated plan and result files are data, not outside code dependencies; the `.mlx` remains standalone.

## 16. Interface design

The interface behaves like a guided engineering worksheet, not a collection of unexplained popups.

### Visual system

- Graphite `#21313A`: primary text and structure.
- Instrument blue `#236C8E`: current step and primary actions.
- Safe teal `#2F7D6D`: supported results.
- Caution amber `#B57519`: assumptions, reserves, and review-needed states.
- Error rust `#A43D35`: invalid or unsafe states.
- Cool white `#F7F9FA`: calm working background.

MATLAB’s readable system font is used with a clear scale: 20 pt page title, 16 pt section title and primary controls, 14 pt questions, and 12–13 pt explanations. Text is left aligned. One visual progress path—Plan → Prepare → Test → Check → Finish—provides orientation; decoration that does not aid a decision is removed.

### Planner layout

```text
Plan → Prepare → Test → Check → Finish

What result do you need?
[ outcome ] [ reliability ] [ confidence ] [ accuracy ]
  explanation under every question

What do you know?
[ expected Interaction gap ] [ expected No-interaction gap ]
[ previous information ]

What can you build?
[ physical setup method ] [ permitted range ]

[ Review plan ]
```

### Result priority

1. supported/not supported decision;
2. reachable operating instruction;
3. middle gap and confidence range;
4. overall variation and explanation;
5. evidence and assumptions;
6. graph and detailed information.

The probability curve is shown alongside, not instead of, the existing distribution view. Visual work follows mathematical and workflow correctness.

## 17. Errors and awkward conditions

Errors explain what happened and what the user can do next. Required cases include:

- missing or invalid percentages;
- confidence below 50%;
- reversed physical expectations;
- permitted maximum not above minimum;
- no reachable gaps;
- required accuracy finer than the physical setup can support;
- repeated requested setting;
- no overlap at a checkpoint;
- failed or unbounded fit;
- confidence boundary outside the permitted range;
- measured readings outside the permitted range;
- reading variation larger than the confirmed physical capability;
- missing plan file or unsupported plan version; and
- an existing save filename.

## 18. Verification and mock laboratory study

Verification covers every defined workflow and representative normal, boundary, invalid, and difficult input class. It does not claim to test every real number individually.

Required verification includes:

- preservation and reference-table regression tests;
- Stage 1, Stage 2, 0.8 shrink, overlap, MLE, D-optimal selection, bounds, rounding, and stopping;
- the confirmed probability-at-gap defect and its correction;
- both planner modes and first-study behaviour;
- confidence values at 10%, below 50%, 50%, 95%, and 99.9%;
- reliability values across the approved range;
- 0.05, 0.10, 0.15, and 0.50 mm physical capabilities;
- irregular reachable-gap lists;
- four/five measurements and new-build variation;
- main and reserve checkpoint behaviour;
- save, reopen, continue, and overwrite protection;
- clean-start standalone `.mlx` operation; and
- visual inspection of every screen and important state.

Synthetic validation uses fixed recorded seeds and saved scenario outputs. Work may be divided across up to four independent MATLAB R2022b processes; each writes a separate shard, and merging verifies expected counts, unique scenarios, and matching configuration before accepting results.

## 19. Overnight report

A separate self-contained HTML report records:

- approved objective and design;
- original problems and newly confirmed defect;
- implemented corrections;
- before-and-after examples;
- executed test and simulation evidence;
- full mock laboratory walkthrough;
- interface screenshots and visual findings;
- standalone `.mlx` verification;
- exact files and save locations;
- unconfirmed physical assumptions; and
- remaining limitations.

The report is saved in the project and copied to `C:\Users\games\OneDrive\CHATGPT-Neyer\`. No PowerPoint is part of this overnight scope.

## 20. Completion boundary

Overnight work is successful only when the approved implementation, focused tests, relevant full suite, calibrated virtual validation, standalone rebuild, clean-start mock workflow, visual inspection, and overnight report have completed with recorded evidence.

If a required mathematical claim fails validation, the tool must state the limitation or withhold the claim. The work is not declared complete merely because the interface opens or because legacy tests pass.

