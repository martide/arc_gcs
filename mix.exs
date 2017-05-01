defmodule Arc.Storage.GCS.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :arc_gcs,
     version: @version,
     elixir: "~> 1.4",
     deps: deps(),
     description: description(),
     package: package()]
  end

  defp description do
    """
    Provides Google Cloud Storage backend for Arc.
    """
  end

  defp package do
    [maintainers: ["Martide"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/martide/arc_gcs"},
     files: ~w(mix.exs README.md lib)]
  end

  defp deps do
    [
      {:goth, "~> 0.4"},
      {:sweet_xml, "~> 0.6"}
    ]
  end
end
