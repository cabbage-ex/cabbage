defmodule Cabbage.Mixfile do
  use Mix.Project

  @version "0.4.0"
  def project do
    [
      app: :cabbage,
      version: @version,
      elixir: "~> 1.3",
      source_url: "git@github.com:cabbage-ex/cabbage.git",
      homepage_url: "https://github.com/cabbage-ex/cabbage",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "Story BDD tool for executing elixir in ExUnit",
      docs: [
        main: Cabbage,
        readme: "README.md"
      ],
      package: package(),
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
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
      {:gherkin, github: "cabbage-ex/gherkin"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:earmark, "~> 1.2", only: :dev},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Matt Widmann", "Steve B"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/cabbage-ex/cabbage"}
    ]
  end

  defp aliases do
    [publish: ["hex.publish", "hex.publish docs", "tag"], tag: &tag_release/1]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as #{@version}")
    System.cmd("git", ["tag", "-a", "v#{@version}", "-m", "v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
