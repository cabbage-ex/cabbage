# Changelog

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
