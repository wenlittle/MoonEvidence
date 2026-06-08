# digest

Responsible for digest types and hash algorithm abstraction.

MVP rules:

- Support `sha256`.
- Parse `sha256:<hex>` strings.
- Compare expected and actual digests.
- Keep crypto dependency details inside this package.

