defmodule Arc.Storage.GCS.Mixfile do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :arc_gcs,
      version: @version,
      elixir: "~> 1.5",
      deps: deps(),
      description: description(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description do
    """
    Provides Google Cloud Storage backend for Arc.
    """
  end

  defp package do
    [
      maintainers: ["Martide"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/martide/arc_gcs"},
      files: ~w(mix.exs README.md lib)
    ]
  end

  defp deps do
    [
      {:arc, "~> 0.8"},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.6", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:goth, "~> 1.0"},
      {:sweet_xml, "~> 0.6"}
    ]
  end
end
