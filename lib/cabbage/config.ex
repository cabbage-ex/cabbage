defmodule Cabbage.Config do
  @moduledoc """
  Handles library configuration.

  ### Global configuration

  Default values out of the box

      config :cabbage,
        global_tags: [],
        test_case: ExUnit.Case,
        base_path: "test/features/"

    - `:global_tags` - provide tags that are assigned to all `Cabbage.Case` test suites.
      Can provide `global_tags: [:multiple, :tags]` or `global_tags: :one_tag`
    - `:test_case` - which test case to use. Can provide custom base template as long as it eventually uses `ExUnit.Case`
    - `:base_path` - base location where all `*.feature` files are located. Path relative from project base path.

  ### Feature case configuration

  `:test_case` and `:base_path` can be overwirten for specific feature case

      use Cabbage.Case,
        feature: "new_feature.feature",
        test_case: OtherThanExUnit.Case,
        base_path: "other/path"

  Note that providing `:test_case` and `:base_path` values without `:feature` will have no effect.

  #### Passing options to `ExUnit.Case`

    use Cabbage.Case,
      feature: "new_feature.feature",
      test_case: OtherThanExUnit.Case,
      base_path: "other/path",
      async: true

  `:async` will be passed further to `OtherThanExUnit.Case`

      use OtherThanExUnit.Case, async: true

  """

  @doc """
  Extract which test case to use.

  Either from specified feature options (`:test_case`) of value from configuration (default: `ExUnit.Case`)
  """
  def test_case(options), do: options[:test_case] || Application.fetch_env!(:cabbage, :test_case)

  @doc """
  Extract options to be passed to base case (default `ExUnit.Case`).
  """
  def test_case_options(options), do: options |> Keyword.split([:test_case, :feature, :base_path]) |> elem(1)

  @doc """
  Determines if feature case has provided feature source file
  """
  def has_feature?(options), do: options[:feature] != nil

  @doc """
  Extract full feature path

  Feature file path combine from two parts:
  - *Base path* - either spcified in feature options (`:base_path`) or taken from configuration (default: `"test/features/"`)
  - *Feature path* - feature options (`:feature`)
  """
  def feature_path(options), do: options |> base_path() |> Path.join(options[:feature])

  @doc """
  Extract all tags

  Combine tags from three parts:
  - *Global configuration* - `:global_tags`
  - *Module specified tags* - via `ExUnit.Case`'s `@moduletag` attribute
  - *Tags provided in feature feature files*
  """
  def tags(options, extra_tags \\ []) do
    global = Application.fetch_env!(:cabbage, :global_tags) |> List.wrap()
    module = options[:env].module |> Module.get_attribute(:moduletag) |> List.wrap()

    global ++ module ++ extra_tags
  end

  defp base_path(options), do: options[:base_path] || Application.fetch_env!(:cabbage, :base_path)
end
