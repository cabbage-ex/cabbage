# Tag Expressions — vendored upstream conformance data

The JSON files under `data/` are mechanically derived from the official
cross-language conformance corpus in the cucumber tag-expressions repo. They are
the same fixtures every other language implementation is validated against, so a
green scoreboard here means byte-for-byte parity with the reference behaviour.

## Provenance

- Upstream: https://github.com/cucumber/tag-expressions
- Commit SHA: `28a5e5e97900b8e6e13d4517a2f24337c6c686fd`
- Source files: `testdata/parsing.yml`, `testdata/evaluations.yml`, `testdata/errors.yml`
- License: MIT (from `cucumber/tag-expressions`); upstream text preserved in [`LICENSE.upstream`](LICENSE.upstream).

## Conversion

YAML was converted to JSON with Ruby (vendor-time only; the library itself uses
the built-in `JSON` module, no `jason` dependency):

```sh
ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load_file(ARGV[0]))' testdata/parsing.yml      > data/parsing.json
ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load_file(ARGV[0]))' testdata/evaluations.yml  > data/evaluations.json
ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load_file(ARGV[0]))' testdata/errors.yml       > data/errors.json
```

## Shapes

- `parsing.json` — list of `{"expression": string, "formatted": string}` (23 cases).
  Parse `expression`, assert `to_string/1 == formatted`, then re-parse `formatted`
  and assert it round-trips to the same canonical form (idempotence).
- `evaluations.json` — list of `{"expression": string, "tests": [{"variables": [string], "result": bool}]}`
  (7 expression groups). Evaluate each sub-case against `variables`, assert `result`.
- `errors.json` — list of `{"expression": string, "error": string}` (15 cases).
  Parsing `expression` must fail with `error` verbatim.
