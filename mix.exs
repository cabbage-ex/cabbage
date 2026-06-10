defmodule Cabbage.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :cabbage,
      version: @version,
      elixir: "~> 1.18",
      source_url: "https://github.com/cabbage-ex/cabbage",
      homepage_url: "https://github.com/cabbage-ex/cabbage",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "A spec-conformant Cucumber runner for Elixir on top of the gherkin fork",
      docs: [
        main: Cabbage,
        readme: "README.md"
      ],
      package: package(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run the conformance scoreboards / suite in the :test environment (where the
  # vendored corpora and harnesses live) without requiring MIX_ENV=test.
  # `conformance.tags` and `conformance.expressions` are Mix.Tasks that print the
  # scoreboards; `conformance` is the alias below that runs the tagged ExUnit suite.
  def cli do
    [
      preferred_envs: [
        "conformance.tags": :test,
        "conformance.expressions": :test,
        "conformance.cck": :test,
        conformance: :test
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support", "test/conformance/cck"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      # Only runtime dependency: the gherkin fork (which is itself jason-free). Coverage
      # uses the built-in `mix test --cover`, so no `excoveralls`/`jason` is pulled in.
      # Points at the gherkin 3.0 proposal branch (cabbage-ex/gherkin#23, on the `next`
      # fork branch) so this builds before that PR merges.
      # RELEASE: replace with {:gherkin, "~> 3.0"} once gherkin 3.0.0 is published to hex (see RELEASING.md).
      {:gherkin, git: "https://github.com/tomasz-tomczyk/gherkin.git", branch: "next"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Matt Widmann", "Steve B", "Max Marcon"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cabbage-ex/cabbage"}
    ]
  end

  defp aliases do
    [
      publish: ["hex.publish", "hex.publish docs", "tag"],
      tag: &tag_release/1,
      # Run the tagged conformance suite (excluded by default). The richer
      # per-corpus scoreboards are `mix conformance.tags` / `mix conformance.expressions`.
      conformance: ["test --only conformance"]
    ]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as #{@version}")
    System.cmd("git", ["tag", "-a", "v#{@version}", "-m", "v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
