defmodule Cabbage do
  @moduledoc """
  """
  def base_path(), do: Application.get_env(:cabbage, :features, "test/features/")
end
