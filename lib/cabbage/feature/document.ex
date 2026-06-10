defmodule Cabbage.Feature.Document do
  @moduledoc """
  The runner-internal representation of a loaded `.feature` file.

  `Cabbage.Feature.Loader` projects the fully-resolved `Gherkin.Pickle` list (from
  `Gherkin.pickles/2`) onto these plain structs, which the `Cabbage.Feature` macro
  then compiles into ExUnit tests. They deliberately mirror only what the runner
  consumes — they are not a parser AST.
  """

  defstruct name: "", file: nil, scenarios: []

  @type t :: %__MODULE__{
          name: String.t(),
          file: String.t() | nil,
          scenarios: [Cabbage.Feature.Scenario.t()]
        }
end

defmodule Cabbage.Feature.Scenario do
  @moduledoc """
  One runnable scenario the runner turns into an ExUnit test: a `name`, its source
  `line`, the ExUnit `tags` (atoms / `{atom, value}`), and its resolved `steps`.
  """

  defstruct name: "", line: 0, tags: [], steps: []

  @type t :: %__MODULE__{
          name: String.t(),
          line: non_neg_integer(),
          tags: [atom() | {atom(), term()}],
          steps: [Cabbage.Feature.Step.t()]
        }
end

defmodule Cabbage.Feature.Step do
  @moduledoc """
  One step inside a `Cabbage.Feature.Scenario`. `keyword` is the display keyword
  (`"Given"`/`"When"`/`"Then"`), already conjunction-resolved by the pickle compiler.
  `table_data` is a list of header-keyed maps (`[]` when absent); `doc_string` is the
  content string (`""` when absent).
  """

  defstruct keyword: "", text: "", table_data: [], doc_string: "", line: 0

  @type t :: %__MODULE__{
          keyword: String.t(),
          text: String.t(),
          table_data: [map()],
          doc_string: String.t(),
          line: non_neg_integer()
        }
end
