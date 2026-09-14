# V1.12 verification matrix

“All possible” cannot mean every decimal number or every possible outcome sequence because those sets are effectively unlimited. This matrix lists 37 checks covering the defined rules and representative workflows, including the supplied spacer sample and five physical gap steps.

| ID | Area | Check | Evidence | Result |
|---|---|---|---|---|
| M01 | One measurement | Accept one finite, nonnegative measured gap | Focused MATLAB suite | PASS |
| M02 | One measurement | Reject blank input | Focused MATLAB suite | PASS |
| M03 | One measurement | Reject two or more readings | Focused MATLAB suite | PASS |
| M04 | One measurement | Reject text, NaN, infinity, and negative input | Focused MATLAB suite | PASS |
| M05 | One measurement | Use the entered measurement as the statistical gap | Focused MATLAB suite | PASS |
| M06 | Traceability | Preserve requested and measured gaps separately | Focused MATLAB suite | PASS |
| M07 | Traceability | Save one measurement without the removed redundant field | Focused MATLAB suite | PASS |
| M08 | Repeated setting | Store a new measurement when the same requested setting is used again | Focused MATLAB suite | PASS |
| O01 | CSV | Show one actual measured gap without a misleading mean or range | Focused MATLAB suite | PASS |
| O02 | HTML | Show the requested gap, actual gap, and outcome without the removed field | Focused MATLAB suite | PASS |
| O03 | Saving | Refuse to replace existing CSV or HTML files | Full MATLAB suite | PASS |
| O04 | Incomplete result | Preserve and save completed tests when no fitted curve exists | Full MATLAB suite | PASS |
| A01 | Reference | Reproduce the recorded Neyer reference-table results | Full MATLAB suite | PASS |
| A02 | Stage 1 | Move in the correct direction and respect prior bounds | Full MATLAB suite | PASS |
| A03 | Stage 2 | Enter at one guessed overall variation | Full MATLAB suite | PASS |
| A04 | Stage 2 | Apply the 0.8 shrink and two-step floor | Full MATLAB suite | PASS |
| A05 | Stage movement | Never return to an earlier stage | Full MATLAB suite | PASS |
| A06 | MLE | Produce a stable positive fitted variation for supported mixed data | Full MATLAB suite | PASS |
| A07 | D-optimal selection | Match the independent known calculation | Full MATLAB suite | PASS |
| A08 | Direction | Treat smaller gaps as more likely to interact | Full MATLAB suite | PASS |
| A09 | Boundaries | Confirm an unexpected boundary result once, then pause and save | Full MATLAB suite | PASS |
| A10 | Reachability | Request only permitted reachable gaps | Full MATLAB suite | PASS |
| A11 | Rounding | Display requested builds with two decimals while retaining calculation precision | Full MATLAB suite | PASS |
| B01 | Spacer batches | Reproduce all three typical thicknesses from the 90 supplied readings | Spacer sample test | PASS |
| B02 | Spacer batches | Reproduce the unrounded 3.674667 mm prediction for one typical spacer of every size | Spacer sample test | PASS |
| S01 | 62-test simulation | 0.05 mm usable step, one reading per article | Five-run audit | PASS |
| S02 | 62-test simulation | 0.10 mm usable step, one reading per article | Five-run audit | PASS |
| S03 | 62-test simulation | 0.15 mm usable step, one reading per article | Five-run audit | PASS |
| S04 | 62-test simulation | 0.25 mm usable step, one reading per article | Five-run audit | PASS |
| S05 | 62-test simulation | 0.50 mm usable step, one reading per article | Five-run audit | PASS |
| U01 | User interface | Input screen asks for one measured gap and omits the removed message | MATLAB UI check | PASS |
| U02 | User interface | Results screen opens after a completed run | MATLAB UI check | PASS |
| P01 | Packaging | V1.12 `.mlx` is standalone in an empty folder | Clean-start check | PASS |
| P02 | Packaging | V1.10 and V1.11 remain preserved | File comparison | PASS |
| G01 | General recorder | Accept and save one valid general measurement | Recorder suite | PASS |
| G02 | General recorder | Reject multiple or invalid measurements | Recorder suite | PASS |
| G03 | General recorder | Refuse to overwrite an existing CSV | Recorder suite | PASS |

All 37 defined checks passed from fresh MATLAB R2022b evidence. This is broad coverage of the defined rules and representative workflows; it is not a claim that every mathematically possible decimal input and response history was enumerated. Foil recipes remain disabled until foil-stack measurements and the practical layer limit are supplied.
