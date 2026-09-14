# V1.13 Stage-2 correction

## What happened

In Stage 2, the method calculated 4.2806 mm during the known-answer replay. With a 0.01 mm usable step, the correct reachable request was therefore 4.28 mm.

V1.12 then replaced that already useful request with 4.21 mm. It did this because its physical safeguard always chose the first grid point beyond the observed Interaction/No-interaction interval.

## Why it mattered

The 4.21 mm request was reachable and outside the interval, but it was not the gap selected by the information calculation. This changed later requests and produced a different final fitted curve.

## What changed

V1.13 first rounds the calculated Neyer request to the configured usable step.

- If that reachable gap is already strictly outside the observed interval, the app keeps it.
- If rounding places it inside or exactly on the interval, the existing boundary-adjacent fallback is used.
- Decimal comparisons use a small tolerance so values such as `0.3` and `3 × 0.1` are treated as the same boundary.
- Confirmed lists and spacer combinations are checked using their actual reachable candidates.
- If requested-gap outcomes cross because the measured builds differ from their requests, the app pauses with all completed data preserved instead of producing a technical error.

There is no paper-table lookup and no exception for a particular test number.

## Verification

- The known-answer replay now requests 4.28 mm at Test 11 and finishes at middle gap 5.3922 mm and overall variation 1.0412 mm.
- A 0.05 mm usable step maps the same raw request to 4.30 mm.
- Five fresh 62-article runs passed their logic and calculation checks.
- The complete MATLAB R2022b suite passed 245 checks, with 0 failed and 0 incomplete.
- The standalone V1.13 Live Script ran from a new folder containing no supporting source files.

## Physical-resolution limit

The varied simulation included 1,600 runs. When the true overall variation was 0.25 mm and the usable gap step was 0.50 mm, only 27% of runs obtained the strict overlap needed to leave Stage 2 within 62 tests. A coarse physical step cannot reveal a much narrower change reliably. This is a limitation of the available physical resolution, not a software-calculation failure.
