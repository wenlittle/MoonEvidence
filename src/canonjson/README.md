# canonjson

Responsible for deterministic JSON serialization.

MVP rules:

- Parse JSON.
- Sort object keys.
- Remove insignificant whitespace.
- Produce stable output for hash calculation.
- Reject unsupported numeric forms until exact canonical number handling is verified.

