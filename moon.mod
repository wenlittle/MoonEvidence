// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "starlittle/MoonEvidence"

version = "0.4.1"

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

import {
  "moonbitlang/x@0.4.45",
}

options(
  exclude: [
    "docs/application",
    "docs/plans",
    "docs/records",
    "docs/report",
    "docs/research",
    "docs/申报书.html",
    "docs/申报书.log",
    "docs/申报书.md",
    "docs/申报书.pdf",
    "docs/申报书.tex",
    "report",
    "showcase",
    "比赛要求.txt",
  ],
)
