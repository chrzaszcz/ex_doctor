# ExDoctor

Lightweight tracing, debugging and profiling tool, that collects traces from your system in an ETS table, putting minimal impact on the system.
After collecting the traces, you can query and analyse them.
By separating data collection from analysis, this tool helps you limit unnecessary repetition and guesswork.

## Quick start

To quickly try it out right now, copy & paste the following to your `iex`:

```elixir
:ssl.start; :inets.start; for p <- ["erlang_doctor/master/src/tr.erl", "ex_doctor/main/lib/ex_doctor.ex"] do {:ok, {{_, 200, _}, _, src}} = :httpc.request("https://raw.githubusercontent.com/chrzaszcz/" <> p); tp = "/tmp/" <> Path.basename(p); File.write!(tp, src); c tp end; import ExDoctor; :tr.start
```

This snippet downloads, compiles and starts two modules:

- `:tr` is the main module of [Erlang Doctor](https://github.com/chrzaszcz/erlang_doctor), which provides all the functionality.
- `ExDoctor` is a small Elixir module, which allows using the Erlang records defined in `tr.hrl`.

The Erlang records are used to allow quick and easy pattern-matching, which is used very frequently in `erlang_doctor`.
Maps are not used, because they can be a lot slower and consume more memory (this is verified by benchmarks).

The easiest way to use it is the following:

```erlang
:tr.trace([YourModule])
YourModule.some_function()
:tr.select()
```

You should see the collected traces for the call and return of `YourModule.some_function/0`.

### Use it during development

You can make Erlang Doctor available in the Erlang/Rebar3 shell during development by cloning it to `EX_DOCTOR_PATH`,
compiling it with `mix`, and loading it in your `~/.iex.exs` file:

```erlang
Code.append_path("EX_DOCTOR_PATH/_build/dev/lib/erlang_doctor/ebin")
Code.append_path("EX_DOCTOR_PATH/_build/dev/lib/ex_doctor/ebin")
import ExDoctor
Code.ensure_loaded!(:tr)
```
