defmodule MobAsh.MixProject do
  use Mix.Project

  @source_url "https://github.com/GenericJam/mob_ash"

  def project do
    [
      app: :mob_ash,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description:
        "Resource-driven Mob screens from Ash: declare Ash resources, get list/detail/create screens on device",
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    # :mob_dev is test-only (the manifest tests run the real pre-publish
    # validator) and never ships.
    # :ash is a REAL runtime dep — it runs ON DEVICE in the host's BEAM (the
    # first mob plugin with a heavyweight pure-Elixir runtime dependency).
    [
      {:mob, "~> 0.7"},
      {:ash, "~> 3.0"},
      {:mob_dev, "~> 0.6", only: [:dev, :test], runtime: false},
      # Code quality — Credo + ex_slop (AI-pattern checks) + jump_credo_checks,
      # mirroring mob core's pre-commit gate.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README* CHANGELOG*)
    ]
  end
end
