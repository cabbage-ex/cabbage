defmodule Cabbage.PendingError do
  @moduledoc """
  Raised inside a step definition to mark the step (and scenario) `PENDING` via an
  exception, mirroring fake-cucumber's `PendingException`.

  The message-emitting runner (`Cabbage.Messages`) rescues this and reports the step
  with status `PENDING` plus an `exception` whose `type` is `"PendingException"` — the
  name the cucumber-messages goldens carry (see the CCK `pending-exception` sample).

  Returning the string `"pending"` from a step also yields `PENDING`, but *without* an
  exception object — the two signalling styles are distinct in the message stream.
  """

  defexception message: "step is pending"
end

defmodule Cabbage.SkippedError do
  @moduledoc """
  Raised inside a step definition to mark the step (and the rest of the scenario)
  `SKIPPED` via an exception, mirroring fake-cucumber's `SkippedException`.

  The message-emitting runner (`Cabbage.Messages`) rescues this and reports the step
  with status `SKIPPED` plus an `exception` whose `type` is `"SkippedException"` (see
  the CCK `skipped-exception` sample). A run whose only non-passed steps are skipped is
  still reported `success: true`.

  Returning the string `"skipped"` from a step also yields `SKIPPED`, but *without* an
  exception object.
  """

  defexception message: "step was skipped"
end
