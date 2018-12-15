defmodule Cabbage.OptionsManager do
  def test_case(options), do: options[:test_case] || Application.fetch_env!(:cabbage, :test_case)
  def has_feature?(options), do: options[:feature] != nil
  def base_path(options), do: options[:base_path] || Application.fetch_env!(:cabbage, :base_path)
  def feature_path(options), do: Path.join(base_path(options), options[:feature])

  def tags(options, extra_tags \\ []) do
    global = Application.fetch_env!(:cabbage, :global_tags) |> List.wrap()
    module = options[:env].module |> Module.get_attribute(:moduletag) |> List.wrap()

    (global ++ module ++ extra_tags)
    |> Enum.map(fn
      {tag, value} -> [{tag, value}]
      tag -> tag
    end)
  end
end
