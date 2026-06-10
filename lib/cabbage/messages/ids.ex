defmodule Cabbage.Messages.Ids do
  @moduledoc """
  A monotonic id/counter source for `Cabbage.Messages`.

  cucumber-messages envelopes carry sequential string ids and increasing timestamps.
  The conformance normalizer drops both (`id`, `nanos`, `seconds`, ...), so the exact
  values never affect comparison — they only need to be present and unique. This module
  hands out a steadily increasing counter for both purposes, keeping the emitted stream
  realistic without coupling correctness to specific numbers.
  """

  @type t :: %__MODULE__{counter: non_neg_integer()}

  defstruct counter: 0

  @doc "A fresh id source starting at 0."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Return the next id (as a string) and the advanced source."
  @spec next(t()) :: {String.t(), t()}
  def next(%__MODULE__{counter: counter} = ids) do
    {Integer.to_string(counter), %{ids | counter: counter + 1}}
  end

  @doc "A monotonic integer derived from the current counter, for timestamps."
  @spec tick(t()) :: non_neg_integer()
  def tick(%__MODULE__{counter: counter}), do: counter
end
