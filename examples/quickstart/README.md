# MoonBit quickstart

Run the library directly from the repository:

```powershell
moon run examples/quickstart
```

The program creates an in-memory manifest, verifies the original two files,
changes one file, and confirms that verification rejects the changed bytes.
It exits successfully only when both the acceptance and rejection paths behave
as expected.
