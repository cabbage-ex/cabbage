# Changelog

### v0.4.0

- Breaks: `Cabbage.Feature` -> `Cabbage.Case`
- Breaks: Providing feature file `file:` -> `feature:`. `use Cabbage.Case, feature: "some.feature"`
- Breaks: features base path key `features` -> `base_path`
- Breaks: removed `defand/4`. All and steps are converted to context (`given`, `when`, `then`)
- Breaks: defining tag specifi setups `tag/2` -> `setup_tag/3`
- Breaks: tests doesn't have default tag `@integration` assigned. Can assign via `global_tags`.
- Added: Can provide global base test case. `base_path` key in config.
- Added: Can provide multiple implementations for single step. Will use first one that pattern-matches

### v0.3.4-dev

- Support for Elixir 1.7 #50.

### v0.3.3
- Support for Elixir 1.5 #38. Thanks to @lboekhorst and @rawkode

### v0.3.2
- Fix for improper state tracking #33. Thanks to @lboekhorst

### v0.3.1
- Better support for missing steps (produces the pattern match for the given missing data). #26 Thanks to @shdblowers
- Breaks `import_feature/1` into two separate macros for more explicit control. Issue #21. Thanks for @hisapy for the suggestion.

### v0.3.0
- Support for running specific tests #15 on a specific line number.
- Bug fix #19 Thanks to @rawkode - Defaulting steps and tags to empty list when get_attributes returns nil
- Missing step advisor improvements #14 Thanks to @shdblowers
- Data tables and doc strings are now available in the variables under the `:table` and `:doc_string` keys

### v0.2.2
- Support for ExUnit case templates. Simply specify the case template module name like
`use Cabbage, template: MyApp.ConnCase, feature: "some_file.feature"`
- Support for tags as ExUnit setup callbacks.

### v0.2.1
- Bug fix #9 Thanks to @shdblowers - Fixes updating of state properly from one step to the next

### v0.2.0
- Support for Scenario Outlines. Scenario Outlines are supported by expanding them into
basic scenarios by filling in all variables. The name of each scenario is appended to have
`(Example x)` where `x` is the row from the `Examples` block in the Scenario Outline. See
https://github.com/cabbage-ex/cabbage/blob/master/test/outline_test.exs for an example.

### v0.1.0

- Initial features to run a simple scenario with variable matching and state tracking.
