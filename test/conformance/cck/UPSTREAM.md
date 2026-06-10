# Cucumber Compatibility Kit (CCK) — vendored corpus

This directory vendors sample data from the
[`cucumber/compatibility-kit`](https://github.com/cucumber/compatibility-kit) repository,
used by `mix conformance.cck` to verify the message-emitting runner (`Cabbage.Messages`)
against the canonical cucumber-messages goldens.

## License

The vendored corpus (the `data/` inputs/goldens and the `reference/` `.ts` step
definitions) is from `cucumber/compatibility-kit`, licensed MIT. The upstream
license text is preserved verbatim in [`LICENSE.upstream`](LICENSE.upstream).

## Pin

| | |
|---|---|
| Upstream repo | `https://github.com/cucumber/compatibility-kit` |
| Commit (SHA)  | `8fa40701e64b25447b89fd1a868921caafd10c5c` |
| Vendored on   | 2026-06-05 |
| protocolVersion in goldens | `31.1.0` (cucumber-messages) |
| Sample areas upstream | 44 (`devkit/samples/`) |

The devkit `package.json` carries the placeholder version `0.0.0`; the commit SHA above
is the authoritative pin.

## Layout

- `data/<area>/` — the vendored inputs and goldens for each sample area:
  - `<area>.feature` (or `<area>.feature.md` for Markdown-Gherkin),
  - `<area>.ndjson` — the GOLDEN full-run cucumber-messages stream,
  - any media / `.arguments.txt` files.
- `reference/<area>/<area>.ts` — the upstream reference step definitions. These are kept
  for reference only (re-implemented in Elixir under `steps.ex`); they are **not** compiled
  or shipped as code.

Only the areas targeted so far are vendored (see `runner.ex` `@samples`). The
status/exception wave added `all-statuses`, `failedish-combinations`, `stack-traces`,
`pending-exception`, and `skipped-exception` (all graded), plus `test-run-exception`
(vendored but deferred: its golden asserts a run-level crash rather than a normal run, so
it is listed `unsupported` in `mix conformance.cck`). The parameter-type wave added
`parameter-types`, `regular-expression`, and `unknown-parameter-type` (all graded).

## Re-vendoring

```sh
git clone --depth 1 https://github.com/cucumber/compatibility-kit /tmp/cck
# copy devkit/samples/<area>/* (except *.ts) into data/<area>/, *.ts into reference/<area>/
```

Record the new SHA in this file when updating.
