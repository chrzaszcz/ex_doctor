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

```elixir
:tr.trace([YourModule])
YourModule.some_function()
:tr.select
```

You should see the collected traces for the call and return of `YourModule.some_function/0`.

### Include it as a dependency

The [package](https://hex.pm/packages/ex_doctor) can be installed by adding `ex_doctor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_doctor, "~> 0.1"}
  ]
end
```

### Use it during development

You can make Erlang Doctor available in the Erlang/Rebar3 shell during development by cloning it to `EX_DOCTOR_PATH`,
compiling it with `mix`, and loading it in your `~/.iex.exs` file:

```elixir
Code.append_path("EX_DOCTOR_PATH/_build/dev/lib/erlang_doctor/ebin")
Code.append_path("EX_DOCTOR_PATH/_build/dev/lib/ex_doctor/ebin")
import ExDoctor
Code.ensure_loaded!(:tr)
```

## Tracing: data collection

You can follow the examples on your own - just call `iex -S mix` in `EX_DOCTOR_PATH`,
and execute the numbered commands in the same order.

### Setting up: `start`, `start_link`

In our case ExDoctor is automatically started by `mix`, but if you need to start it yourself, call `:tr.start()`.
There is `:tr.start_link()` as well, but it is intended for use with the whole application.
Both functions can also take an argument, which is a map of options with the following keys:

- `tab`: collected traces are stored in an ETS table with this name (default: `:trace`),
- `limit`: maximum number of traces in the table - when it is reached, tracing is stopped (default: no limit).

Let's set up an alias for the `Example` module, because it will be used very often:

```elixir
iex(1)> alias ExDoctor.Example
ExDoctor.Example
```

### Tracing with `trace`

To trace function calls for given modules, use `:tr.trace/1`, providing a list of traced modules:

```elixir
iex(2)> :tr.trace([Example])
:ok
```

You can provide `{module, function, arity}` tuples in the list as well.
To get a list of all modules from an application, use `:tr.app_modules/1`.
`:tr.trace(:tr.app_modules(:your_app))` would trace all modules from `your_app`.
There is a shortcut as well: `:tr.trace_app(:your_app)`.
If you want to trace selected processes instead of all of them, you can use
`:tr.trace(modules, pids)`, which is a shortcut for `:tr.trace(%{modules: modules, pids: pids})`.
In fact, `:tr.trace(modules)` is a shortcut for `:tr.trace(%{modules: modules})`,
and the `trace/1` function accepts a map of options with the following keys:

- `modules`: a list of module names or `{module, function, arity}` tuples. The list is empty by default.
- `pids`: a list of Pids of processes to trace, or `:all` (default) to trace all processes.
- `msg`: `:none` (default), `:all`, `:send` or `:recv`. Specifies which message events will be traced. By default no messages are traced.
- `msg_trigger`: `:after_traced_call` (default) or `:always`. By default, traced messages in each process are stored after the first traced function call in that process. The goal is to limit the number of traced messages, which can be huge in the entire Erlang system. If you want all messages, set it to `:always`.

Now we can call some functions - let's trace the following function call.
It calculates the factorial recursively and sleeps 1 ms between each step.

```elixir
iex(3)> Example.sleepy_factorial(3)
6
```

### Stopping tracing

You can stop tracing with the following function:

```elixir
iex(4)> :tr.stop_tracing()
:ok
```

It's good to stop it as soon as possible to avoid accumulating too many traces in the ETS table.
Usage of `tr` on production systems is risky, but if you have to do it, start and stop the tracer in the same command,
e.g. for one second with:

```elixir
:tr.trace(modules); :timer.sleep(1000); :tr.stop_tracing()
```

## Debugging: data analysis

The collected traces are stored in an ETS table (default name: `:trace`).
They are stored as `tr` records with the following fields:

- `index`: trace identifier, auto-incremented for each received trace.
- `pid`: process ID associated with the trace.
- `event`: `:call`, `:return` or `:exception` for function traces; `:send` or `:recv` for messages.
- `mfa`: an MFA tuple: module name, function name and function arity; undefined for messages.
- `data`: argument list (for calls), returned value (for returns) or class and value (for exceptions).
- `timestamp` in microseconds.
- `extra`: only for `:send` events; `msg` record with the following fields:
    - `to`: message recipient (Pid),
    - `exists`: boolean, indicates if the recipient process existed.

You can load the record definitions with `import ExDoctor`, but in our case `mix` has done it for us.
The snippets shown at the top of this README do it as well.

### Trace selection: `select`

Use `:tr.select/0` to select all collected traces, which include a system call to `__info__/1`
followed by the call to `sleepy_factorial/1`.

```elixir
iex(5)> :tr.select()
[
  {:tr, 1, #PID<0.187.0>, :call, {ExDoctor.Example, :__info__, 1},
   [:deprecated], 1705413018330494, :undefined},
  {:tr, 2, #PID<0.187.0>, :return, {ExDoctor.Example, :__info__, 1}, [],
   1705413018330501, :undefined},
  {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [3],
   1705413018330532, :undefined},
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :undefined},
  {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [1],
   1705413018334514, :undefined},
  {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [0],
   1705413018336506, :undefined},
  {:tr, 7, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 1,
   1705413018338509, :undefined},
  {:tr, 8, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 1,
   1705413018338511, :undefined},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :undefined},
  {:tr, 10, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 6,
   1705413018338513, :undefined}
]
```

The `:tr.select/1` function accepts a fun that is passed to `:ets.fun2ms/1`.
This way you can limit the selection to specific items and select only some fields from the `tr` record:

```elixir
iex(6)> :tr.select(fn tr(event: :call, data: [n]) when is_integer(n) -> n end)
[3, 2, 1, 0]
```

Use `:tr.select/2` to further filter the results by searching for a term in the `data` field
(recursively searching in lists, tuples and maps).

```elixir
iex(7)> :tr.select(fn t -> t end, 2)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :undefined},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :undefined}
]
```

### Trace filtering: `filter`

Sometimes it might be easier to use `:tr.filter/1`, because it can accept any function as the argument.
You can use `:tr.contains_data/2` to search for a term like in the example above.

```elixir
iex(8)> traces = :tr.filter(fn t -> :tr.contains_data(2, t) end)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :undefined},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :undefined}
]
```

The provided function is a predicate, which has to return `:true` for the matching traces.
For other traces it can return another value, or even raise an exception:

```elixir
iex(9)> :tr.filter(fn tr(data: [2]) -> :true end)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :undefined}
]
```

There is also `:tr.filter/2`, which can be used to search in a different table than the current one - or in a list:

```elixir
iex(10)> :tr.filter(fn tr(event: :call) -> :true end, traces)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :undefined}
]
```

### Tracebacks for filtered traces: `tracebacks`

To find the tracebacks (stack traces) for matching traces, use `:tr.tracebacks/1`:

```elixir
iex(11)> :tr.tracebacks(fn tr(data: 1) -> true end)
[
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :undefined},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :undefined},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :undefined}
  ]
]
```

Note, that by specifying `data: 1` we are only matching return traces, as call traces always have a list in `data`.
Only one traceback is returned. It starts with a call that returned `1`. What follows is the stack trace for this call.

One can notice that the call for 0 also returned 1, but the call tree got pruned - whenever two tracebacks overlap, only the shorter one is left.
You can change this by returning tracebacks for all matching traces even if they overlap, setting the `output` option to `:all`. All options are specified in the second argument, which is a map:

```elixir
iex(12)> :tr.tracebacks(fn tr(data: 1) -> true end, %{output: :all})
[
  [
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :undefined},
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :undefined},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :undefined},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :undefined}
  ],
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :undefined},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :undefined},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :undefined}
  ]
]
```

The third possibility is `:longest`, which does the opposite of pruning, leaving only the longest tracabacks when they overlap:

```elixir
iex(13)> :tr.tracebacks(fn tr(data: 1) -> true end, %{output: :longest})
[
  [
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :undefined},
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :undefined},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :undefined},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :undefined}
  ]
]
```

All possible options for `tracebacks/2`:

- `tab` is the table or list which is like the second argument of `:tr.filter/2`,
- `output` - `:shortest` (default), `:all`, `:longest` - see above.
- `format` - `:list` (default), `:tree` - returns a call tree instead of a list of tracebacks. Trees don't distinguish between `all` and `longest` output formats.
- `order` - `:top_down` (default), `:bottom_up` - call order in each tracaback; only for the `:list` format.
- `limit` - positive integer or `:infinity` (default) - limits the number of matched traces. The actual number of tracebacks returned can be smaller unless `output` is set ot `:all`

There are also functions `traceback/1` and `traceback/2`. They set `limit` to one and return only one trace if it exists. The options for `traceback/2` are the same as for `traceback/2` except `limit` and `format`. Additionally, it is possible to pass a `tr` record (or an index) directly to `traceback/1` to obtain the traceback for the provided trace event.

### Trace ranges for filtered traces: `ranges`

To get a list of traces between each matching call and the corresponding return, use `:tr.ranges/1`:

```elixir
iex(14)> :tr.ranges(fn tr(data: [1]) -> true end)
[
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :undefined},
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :undefined},
    {:tr, 7, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1},
     1, 1705413018338509, :undefined},
    {:tr, 8, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1},
     1, 1705413018338511, :undefined}
  ]
]
```

There is also `:tr.ranges/2` - it accepts a map of options with the following keys:

- `tab` is the table or list which is like the second argument of `:tr.filter/2`,
- `max_depth` is the maximum depth of nested calls. A message event also adds 1 to the depth.
    You can use `%{max_depth: 1}` to see only the top-level call and the corresponding return.

There are two additional functions: `:tr.range/1` and `:tr.range/2`, which return only one range if it exists. It is possible to pass a `tr` record or an index to `:tr.range/1` as well.

### Calling function from a trace: `do`

It is easy to replay a particular function call with `:tr.do/1`:

```elixir
iex(15)> [t] = :tr.filter(fn tr(data: [3]) -> true end)
[
  {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [3],
   1705413018330532, :undefined}
]
iex(16)> :tr.do(t)
6
```

This is useful e.g. for checking if a bug has been fixed without running the whole test suite.
This function can be called with an index as the argument.

### Getting a single trace for the index: `lookup`

Use `:tr.lookup/1` to obtain the trace for an index.

## Profiling

You can quickly get a hint about possible bottlenecks and redundancies in your system with function call statistics.

### Call statistics: `call_stat`

The argument of `:tr.call_stat/1` is a function that returns a key by which the traces are grouped.
The simplest way to use this function is to look at the total number of calls and their time.
To do this, we group all calls under one key, e.g. `total`:

```elixir
iex(17)> :tr.call_stat(fn _ -> :total end)
%{total: {5, 7988, 7988}}
```

Values of the returned map have the following format (time is in microseconds):

```{call_count, acc_time, own_time}```

In the example there are four calls, which took 7703 microseconds in total.
For nested calls we only take into account the outermost call, so this means that the whole calculation took 7.703 ms.
Let's see how this looks like for individual steps - we can group the stats by the function argument:

```elixir
iex(18)> :tr.call_stat(fn tr(data: [n]) -> n end)
%{
  0 => {1, 2003, 2003},
  1 => {1, 3997, 1994},
  2 => {1, 5990, 1993},
  3 => {1, 7981, 1991},
  :deprecated => {1, 7, 7}
}
```

You can use the provided function to do filtering as well - let's make the output cleaner
by filtering out the unwanted call to `__info__(:deprecated)`:

```elixir
iex(19)> :tr.call_stat(fn tr(data: [n]) when is_integer(n) -> n end)
%{
  0 => {1, 2003, 2003},
  1 => {1, 3997, 1994},
  2 => {1, 5990, 1993},
  3 => {1, 7981, 1991}
}
```

### Sorted call statistics: `sorted_call_stat`

You can sort the call stat by accumulated time, descending:

```elixir
iex(20)> :tr.sorted_call_stat(fn tr(data: [n]) when is_integer(n) -> n end)
[{3, 1, 7981, 1991}, {2, 1, 5990, 1993}, {1, 1, 3997, 1994}, {0, 1, 2003, 2003}]
```

The first element of each tuple is the key, the rest is the same as above.
To pretty-print it, use `:tr.print_sorted_call_stat/2`.
The second argument limits the table row number, e.g. we can only print the top 3 items:

```elixir
iex(21)> :tr.print_sorted_call_stat(fn tr(data: [n]) when is_integer(n) -> n end, 3)
3  1  7981  1991
2  1  5990  1993
1  1  3997  1994
:ok
```

### Call tree statistics: `top_call_trees`

This function makes it possible to detect complete call trees that repeat several times,
where corresponding function calls and returns have the same arguments and return values, respectively.
When such functions take a lot of time and do not have useful side effects, they can be often optimized.

As an example, let's trace the call to a function which calculates the 4th element of the Fibonacci Sequence
in a recursive way. The `trace` table should be empty, so let's clean it up first:

```elixir
iex(22)> :tr.clean()
:ok
iex(23)> :tr.trace([{Example, :fib, 1}])
ok
iex(24)> Example.fib(4)
3
iex(25)> :tr.stop_tracing()
:ok
```

Now it is possible to print the most time consuming call trees that repeat at least twice:

```elixir
iex(26)> :tr.top_call_trees()
[
  {13, 2,
   {:node, ExDoctor.Example, :fib, [2],
    [
      {:node, ExDoctor.Example, :fib, [1], [], {:return, 1}},
      {:node, ExDoctor.Example, :fib, [0], [], {:return, 0}}
    ], {:return, 1}}},
  {5, 3, {:node, ExDoctor.Example, :fib, [1], [], {:return, 1}}}
]
```

The resulting list contains tuples `{time, count, tree}` where `time` is the accumulated time (in microseconds) spent in the tree,
and `count` is the number of times the tree repeated. The list is sorted by `time`, descending.
In the example above `fib(2)` was called twice and `fib(1)` was called 3 times,
what already shows that the recursive implementation is suboptimal.

There is also `top_call_trees/1` that takes a map of options with the following keys:
- `output` is `:reduced` by default, but it can be set to `:complete` where subtrees of already listed trees are also listed.
- `min_count` is the minimum number of times a tree has to occur to be listed, the default is 2.
- `min_time` is the minimum accumulated time for a tree, by default there is no minimum.
- `max_size` is the maximum number of trees presented, the default is 10.

As an exercise, try calling `:tr.top_call_trees(%{min_count: 1000})` for `fib(20)`.

## Exporting and importing traces

To get the current table name, use `:tr.tab/0`:

```elixir
iex(27)> :tr.tab()
:trace
```

To switch to a new table, use `:tr.set_tab/1`. The table need not exist.

```elixir
iex(28)> :tr.set_tab(:tmp)
:ok
```

Now you can collect traces to the new table without changing the original one.

```elixir
iex(29)> :tr.trace([Enum]); Enum.to_list(1..10); :tr.stop_tracing()
:ok
iex(30)> :tr.select()
[
  (...)
]
```

You can dump the current table to file:

```elixir
iex(31)> :tr.dump(~c"tmp.ets")
:ok
```

In a new `iex` session we can load the data with `:tr.load/1`. This will set the current table name to `:tmp`.

```elixir
iex(1)> :tr.load(~c"tmp.ets")
{:ok, :tmp}
iex(2)> :tr.select()
[
  (...)
]
iex(3)> :tr.tab()
:tmp
```

Finally, you can remove all traces from the ETS table with `:tr.clean/0`.

```elixir
iex(4)> :tr.clean()
:ok
```

To stop `ExDoctor`, just call `:tr.stop/0`.
