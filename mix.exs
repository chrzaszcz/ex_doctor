defmodule ExDoctor.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_doctor,
      description: "Lightweight tracing, debugging and profiling utility",
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ExDoctor",
      source_url: "https://github.com/chrzaszcz/ex_doctor",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:erlang_doctor, "~> 0.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/chrzaszcz/ex_doctor"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
