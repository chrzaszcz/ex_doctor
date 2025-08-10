defmodule ExDoctor do
  require Record

  @moduledoc """
  This module provides an Elixir interface to the erlang_doctor's `:tr` module.
  It defines records and delegates all functions to the underlying Erlang implementation.

  The records are obtained by calling `Record.extract_all(from_lib: "erlang_doctor/src/tr.erl")`

  This module can be dynamically loaded without access to `tr.erl`, so they are listed literally.
  """

  @records [
    tr: [
      index: :undefined,
      pid: :undefined,
      event: :undefined,
      mfa: :no_mfa,
      data: :undefined,
      ts: :undefined,
      info: :no_info
    ],
    node: [
      module: :undefined,
      function: :undefined,
      args: :undefined,
      children: [],
      result: :undefined
    ]
  ]

  for {name, fields} <- @records do
    Record.defrecord(name, fields)
  end

  # API - capturing, data manipulation
  defdelegate start_link(), to: :tr
  defdelegate start_link(opts), to: :tr
  defdelegate start(), to: :tr
  defdelegate start(opts), to: :tr
  defdelegate trace_app(app), to: :tr
  defdelegate trace_apps(apps), to: :tr
  defdelegate trace(modules), to: :tr
  defdelegate trace(modules, pids), to: :tr
  defdelegate stop_tracing(), to: :tr
  defdelegate stop(), to: :tr
  defdelegate tab(), to: :tr
  defdelegate set_tab(tab), to: :tr
  defdelegate load(file), to: :tr
  defdelegate dump(file), to: :tr
  defdelegate clean(), to: :tr

  # API - analysis
  defdelegate select(), to: :tr
  defdelegate select(f), to: :tr
  defdelegate select(f, data_val), to: :tr
  defdelegate filter(f), to: :tr
  defdelegate filter(f, tab), to: :tr
  defdelegate traceback(pred), to: :tr
  defdelegate traceback(pred, options), to: :tr
  defdelegate tracebacks(pred_f), to: :tr
  defdelegate tracebacks(pred_f, options), to: :tr
  defdelegate roots(trees), to: :tr
  defdelegate root(tree), to: :tr
  defdelegate range(pred_f), to: :tr
  defdelegate range(pred_f, options), to: :tr
  defdelegate ranges(pred_f), to: :tr
  defdelegate ranges(pred_f, options), to: :tr
  defdelegate call_tree_stat(), to: :tr
  defdelegate call_tree_stat(options), to: :tr
  defdelegate reduce_call_trees(tree_tab), to: :tr
  defdelegate top_call_trees(), to: :tr
  defdelegate top_call_trees(options), to: :tr
  defdelegate top_call_trees(tree_tab, options), to: :tr
  defdelegate print_sorted_call_stat(key_f, limit), to: :tr
  defdelegate sorted_call_stat(key_f), to: :tr
  defdelegate call_stat(key_f), to: :tr
  defdelegate call_stat(key_f, tab), to: :tr

  # API - utilities
  defdelegate contains_data(data_val, tr), to: :tr
  defdelegate do(tr), to: :tr
  defdelegate lookup(index), to: :tr
  defdelegate app_modules(app_name), to: :tr
  defdelegate mfarity(mfa), to: :tr
  defdelegate mfargs(mfa, args), to: :tr
  defdelegate ts(tr), to: :tr
end
