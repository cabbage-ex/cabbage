defmodule Cabbage.Steps do
  @moduledoc """
  A lightweight step library: a module of reusable step definitions that is **not**
  an ExUnit case and generates no tests.

  Use it to share step definitions across feature modules:

      defmodule MyApp.SharedSteps do
        use Cabbage.Steps

        defstep "I am logged in as {string}", [user], _ctx do
          {:ok, %{user: user}}
        end
      end

  Then import them into a feature module via the `:import` option:

      defmodule MyApp.CheckoutTest do
        use Cabbage.Feature, file: "checkout.feature", import: [MyApp.SharedSteps]

        # local steps here; local steps win over imported ones on a tie
      end

  `use Cabbage.Steps` brings in the step macros (`defstep`/`defgiven`/`defwhen`/`defthen`/`defand`/`defbut`)
  and the `tag` macro, accumulates them into `@steps`/`@tags`, and emits `raw_steps/0`,
  `raw_tags/0` and `__cabbage_document__/0` (the same accessor surface a file-less
  `Cabbage.Feature` exposes) so the module is a drop-in import source. It does **not**
  `use ExUnit.Case` and defines no tests. It imports the full `Cabbage.Feature` macro
  surface, so `import_steps/1`, `import_tags/1` and `import_feature/1` also work inside
  a step module — step libraries compose transitively.

  ## Compilation order

  A step module must be compiled *before* the feature module that imports it. Place step
  modules under a path that compiles first — for ExUnit projects that is `test/support`,
  which must be on `elixirc_paths(:test)`:

      defp elixirc_paths(:test), do: ["lib", "test/support"]
      defp elixirc_paths(_), do: ["lib"]

  Phoenix projects already configure this. If an imported module has not been compiled
  (or is not a step module), `use Cabbage.Feature, import: [...]` raises a clear error
  reporting that the module is missing `raw_steps/0`.
  """
  defmacro __using__(_options) do
    Module.register_attribute(__CALLER__.module, :steps, accumulate: true)
    Module.register_attribute(__CALLER__.module, :imported_steps, accumulate: true)
    Module.register_attribute(__CALLER__.module, :tags, accumulate: true)

    quote do
      @before_compile {Cabbage.Feature, :expose_metadata}
      import Cabbage.Feature
      require Logger
    end
  end
end
