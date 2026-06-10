# JCS Vector Skip List (L1 number policy)

The canonjson package currently implements the L1 "safe subset" number
policy: integers within +/-(2^53 - 1) render exactly; every other number
raises `CanonError::UnsupportedNumber`. Vectors that require ECMAScript
shortest-round-trip number formatting (L2, master plan step 8) are therefore
not yet exercised:

| Skipped vector | Reason |
| --- | --- |
| cyberphone `input.json` / `output.json` (full mixed vector) | Contains `333333333.33333329`, `1E30`, `4.50`, `2e-3`, `0.000000000000000000000000001` - all require L2 shortest-form rendering |
| cyberphone `values.json` | Contains `9223372036854775807` (2^63 - 1), which JCS renders with double-precision loss as `9223372036854776000`; L1 refuses lossy output by design |
| RFC 8785 Appendix B number table (`numbers.input.txt`) | Pure L2 formatting matrix (ES6 shortest representation) |

Every skipped case is covered by negative tests asserting that
`UnsupportedNumber` is raised instead of producing a wrong digest
(`src/canonjson/canonjson_wbtest.mbt`, number policy section).

When L2 lands (step 8), move these vectors into
`canonjson_jcs_wbtest.mbt` and delete this file.
