defmodule Cabbage do
  @moduledoc """
  """
  def base_path(), do: Application.get_env(:cabbage, :features, "test/features/")
  def global_tags(), do: Application.get_env(:cabbage, :global_tags, []) |> List.wrap()
end
