# V2 final visual review

Reviewed at original PNG resolution in MATLAB R2022b on 2026-09-14. Decision: PASS after the limits-paragraph correction. All 16 PNGs in this folder were inspected. Adjacent sections may cross the Help viewport edge; every complete section is readable in its own scrolled view.

| Image | Clipping, overlap and readability | Meaning and wording |
|---|---|---|
| 01-main-menu.png | Pass: the full two-line instruction is visible. | Direct testing and the optional planner are separate. |
| 02-direct-inputs.png | Pass: explanations, values and action buttons are readable. | Regular step is distinct from foil thickness. |
| 02-direct-inputs-confirmed-list.png | Pass: the example list and its explanation are visible. | Only confirmed measured, buildable gaps are requested. |
| 03-test-request.png | Pass: one prominent request and one measurement field. | The request is 5.00 mm; one new setup receives one reading. |
| 04-unfinished-result.png | Pass: no blank charts, overlap or disabled fragments. | Clear status, completed/outcome counts, next action and Save results button. |
| 05-calculated-result.png | Pass: both complementary charts and controls remain readable. | About-50% middle, variation, correct decreasing direction and plain explanation. |
| 06-help.png | Pass. | Introduction and every input explanation are readable. |
| 06-help-section-02.png | Pass. | The complete input explanation is visible. |
| 06-help-section-03.png | Pass. | Complete regular-step versus confirmed-list explanation. |
| 06-help-section-04.png | Pass. | Complete new-setup, one-reading and one-test procedure. |
| 06-help-section-05.png | Pass. | Unfinished versus calculated results explained without invented answers. |
| 06-help-section-06.png | Pass. | Probability and confidence are distinguished. |
| 06-help-section-07.png | Pass. | Saving and reopening: both destinations are shown before saving; nothing is overwritten. |
| 06-help-section-08.png | Pass after correction. | Full boundary, confidence and fixed-gap qualification warnings are visible. |
| 06-help-section-09.png | Pass after correction. | Complete limits and immediately defined technical terms. |
| 06-help-bottom.png | Pass after correction. | The final qualification warning and complete method section are readable. |

Two-decimal formatting applies to requested build gaps, not the measured entry or arbitrary typed starting guesses. Save paths are chosen when saving, so a concrete path is not expected on the initial results screen. The visible Help explains both destinations and collision protection; the clean-start gate separately wrote actual CSV/HTML files, checked their intended paths and rejected a collision without replacement.

The first lower-Help capture found that 13 blank-line-separated fragments overflowed a fixed-height panel. Grouping the text into its intended three complete paragraphs fixed this without changing the wording. Final screenshots include the formerly hidden confidence-above-95% and separate-qualification warnings.
