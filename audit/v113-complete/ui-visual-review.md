# V1.13 visual review

Review date: 2026-09-14  
Source: real MATLAB R2022b windows captured from the frozen V1.13 Live Script  
Evidence: `audit/v113-complete/ui/01-main-menu.png` through `07-pre-test-planner.png`

| Screen | What works | Finding | Importance | User effect |
|---|---|---|---|---|
| Main menu | The planner and direct test are visibly separate. The direct test is the main green action. | The sentence explaining that separation is cut off with `...`. | Important | A central instruction is hidden on the first screen. |
| Direct-run inputs | Inputs are grouped in one clean screen and defaults are visible. | “Rough guess of the overall variation” and “usable gap step” are not explained beside their fields. | Important | A non-specialist must guess what two decision-driving inputs mean. This already caused confusion in a real run. |
| Test entry | The requested gap, one measurement, and the two possible outcomes are prominent. | “Build a gap of 5.00 mm” is immediately repeated as “Set the gap to 5.00 mm.” | Minor | The main instruction is less crisp than it should be. |
| Fitted result | It clearly separates the middle, variation, direction, measured outcomes, and chance curve. It does not call the middle gap 99% reliable. | Terms such as “fitted result” and “confidence-backed minimum” are used without an immediate plain-language definition. | Important | The calculations are right, but the wording can make the decision harder to understand. |
| Unfinished result | It honestly states that a result is not established and does not display NaN values. | Two empty charts and partly visible calculator controls remain on screen even though they cannot be used. | Important | The screen looks unfinished or broken at exactly the point when the user needs a clear explanation. |
| Help | It covers setup, measurement, direction, boundaries, and result meanings. | It is a dense monospaced text wall and includes unexplained terms such as “Stage-2 planning width.” | Important | The help is accurate but difficult to scan and is not jargon-free. |
| Pre-Test Planner | It uses plain questions, short explanations, a separate review area, and clearly labels quantities as estimates. | The long input side requires scrolling, but its structure remains visible and understandable. | Pass | The planner is visibly separate and does not pretend its preparation quantity is a final reliability result. |

## Visual decision

V1.13 is functionally usable, but it does **not** pass the golden-unit design gate. The evidence supports a separate V1.14 user-interface correction after the remaining calculation, simulation, record, and standalone gates are finished. The frozen V1.13 file has not been edited.
