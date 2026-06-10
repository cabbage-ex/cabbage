defmodule Cabbage.Messages.MapHelpers do
  @moduledoc false

  # Shared map helper for the message-emitting runner's envelope builders
  # (`Cabbage.Messages`, `Cabbage.Messages.Matcher`, `Cabbage.Messages.Attach`).

  @doc "Put `key => value` only when `value` is non-nil; otherwise return `map` unchanged."
  @spec put_unless_nil(map(), term(), term()) :: map()
  def put_unless_nil(map, _key, nil), do: map
  def put_unless_nil(map, key, value), do: Map.put(map, key, value)
end
