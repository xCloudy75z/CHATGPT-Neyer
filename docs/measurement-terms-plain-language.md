# Measurement terms in plain language

| Term | Plain meaning | How the software uses it |
|---|---|---|
| Nominal spacer size | The name printed or assigned to a spacer, such as 1.00 mm | Construction information; it is not automatically treated as the achieved gap |
| Requested build gap | The gap the software asks the operator to prepare | Stored as the original instruction and displayed with two decimals |
| Reachable gap | A permitted setting that the physical setup is configured to build | The software chooses its next request from these settings |
| Usable gap step | The smallest confirmed spacing between settings the study agrees to treat as separately buildable | Controls the reachable setting list and the Stage-2 planning floor |
| Actual measured gap | The one measurement entered for the completed setup | Used as that article's gap in the statistical calculation |
| Measurement count | How many readings were taken from that completed setup | V1.11 records one |
| Measurement uncertainty | How much the measurement itself could differ if repeated | Recorded as **not assessed** when only one reading is taken |
| Part-to-part variation | Differences between separately manufactured spacers with the same label | Part of the real physical process; it is not the same as measurement uncertainty |
| Observed range | Largest measured part minus smallest measured part | Describes only the samples measured; it is not a guaranteed future limit |
| Middle gap | The fitted gap with about a 50% chance of interaction | Estimated after the data contain enough useful mixed outcomes |
| Overall variation | How quickly or gradually outcomes change around the middle gap | Estimated by the Neyer model from results across independently prepared articles |

## Example

The software requests **2.50 mm**. A newly prepared setup is measured once at **2.54 mm**.

- Requested build gap: 2.50 mm
- Actual measured gap used in the calculation: 2.54 mm
- Measurement count: 1
- Measurement uncertainty: not assessed

The software keeps both 2.50 mm and 2.54 mm. It does not replace the measurement with the request, and it does not claim that the single measurement is perfectly accurate.
