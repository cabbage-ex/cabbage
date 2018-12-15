defmodule Cabbage.Feature.OptionsManager do
  def test_case(options), do: options[:test_case] || Application.fetch_env!(:cabbage, :test_case)
  def feature(options), do: options[:feature]
  def has_feature?(options), do: feature(options) != nil
end
