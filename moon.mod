// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "starlittle/MoonEvidence"

version = "0.3.0"

readme = "README.md"

repository = "https://github.com/wenlittle/MoonEvidence.git"

license = "Apache-2.0"

keywords = [
  "evidence",
  "verification",
  "canonical-json",
  "merkle",
  "provenance",
]

description = "Trusted evidence pack verification library and CLI for MoonBit."

options(
  exclude: [
    "docs/plans",
    "docs/research",
    "docs/report",
    "docs/records",
  ],
)

import {
  "moonbitlang/x@0.4.45",
}
