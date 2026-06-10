# Cucumber Expressions conformance testdata

The JSON fixtures under `data/` are vendored from the official, language-neutral
Cucumber Expressions test suite and converted from YAML to JSON at vendor time.

- Source: https://github.com/cucumber/cucumber-expressions
- Upstream commit: `0555a711a741421ca31255f16b3c5a97625d20d2`
- Vendored: 2026-06-05
- License: MIT (from `cucumber/cucumber-expressions`); upstream text preserved in [`LICENSE.upstream`](LICENSE.upstream).

## Conversion

Each upstream `testdata/**/*.yaml` file was converted with Ruby:

```sh
ruby -ryaml -rjson -e 'print JSON.generate(YAML.load_file(ARGV[0]))' file.yaml
```

Loading at test time uses the built-in Elixir 1.18 `JSON` module (`JSON.decode!/1`).

## Categories and counts (115 files total)

| Local dir            | Upstream path                                   | Count |
| -------------------- | ----------------------------------------------- | ----- |
| `data/matching`      | `testdata/cucumber-expression/matching`         | 62    |
| `data/parser`        | `testdata/cucumber-expression/parser`           | 27    |
| `data/tokenizer`     | `testdata/cucumber-expression/tokenizer`        | 15    |
| `data/transformation`| `testdata/cucumber-expression/transformation`   | 8     |
| `data/regex`         | `testdata/regular-expression/matching`          | 3     |

## Case shapes

- matching: `{expression, text, expected_args}` OR `{expression, text, exception}`
- parser: `{expression, expected_ast}` OR `{expression, exception}`
- tokenizer: `{expression, expected_tokens}` OR `{expression, exception}`
- transformation: `{expression, expected_regex}`
- regex: `{expression, text, expected_args}` (regular-expression matching, not cucumber expressions)
