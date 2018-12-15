use Mix.Config

config :logger, level: :error

config :cabbage,
  global_tags: [],
  test_case: ExUnit.Case,
  base_path: "test/features/"
