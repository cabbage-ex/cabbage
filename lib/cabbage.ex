defmodule Cabbage do
  @moduledoc """
  A spec-conformant Cucumber runner for Elixir.

  This module only holds the small amount of application configuration the loader reads
  (`:features`, `:global_tags`). The runner itself lives in two complementary modules:

    * `Cabbage.Feature` — **the one you use.** `use Cabbage.Feature, file: ...` compiles a
      `.feature` file into ExUnit tests at compile time, so scenarios run under `mix test`
      with ordinary `defgiven/defwhen/defthen` step definitions.
    * `Cabbage.Messages` — a runtime cucumber-messages interpreter. It executes pickles
      directly and emits the cucumber-messages `Envelope` stream; this is the path graded
      against the Cucumber Compatibility Kit (CCK). You rarely call it directly.

  `Cabbage.Formatter` bridges the two: an ExUnit formatter that emits the same
  cucumber-messages NDJSON stream while your `Cabbage.Feature` tests run.

  > #### "Messages" vs "Message" {: .neutral}
  >
  > `Cabbage.Messages` is the runtime runner. The cucumber-messages *envelope builders* it
  > reuses come from the gherkin dependency as `Gherkin.Message` — different things.
  """

  @doc "The directory feature files are loaded from (config `:cabbage, :features`)."
  @spec base_path() :: String.t()
  def base_path(), do: Application.get_env(:cabbage, :features, "test/features/")

  @doc "Tags applied to every generated scenario (config `:cabbage, :global_tags`)."
  @spec global_tags() :: [atom() | String.t()]
  def global_tags(), do: Application.get_env(:cabbage, :global_tags, []) |> List.wrap()
end
