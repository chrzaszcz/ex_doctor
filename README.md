# ExDoctor
[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_doctor)](https://hex.pm/packages/ex_doctor)
[![Hex Docs](https://img.shields.io/badge/hex-docs-yellow.svg)](https://hexdocs.pm/ex_doctor/)

Lightweight tracing, debugging and profiling tool powered by [Erlang Doctor](https://hex.pm/packages/erlang_doctor).
It collects traces from your Elixir system in an ETS table, putting minimal impact on the system.
After collecting the traces, you can query and analyse them.
By separating data collection from analysis, this tool helps you limit unnecessary repetition and guesswork.

## Quick start

To quickly try it out right now, copy & paste the following to your `iex`:

```elixir
:ssl.start; :inets.start; for p <- ["erlang_doctor/master/src/tr.erl", "ex_doctor/main/lib/ex_doctor.ex"] do {:ok, {{_, 200, _}, _, src}} = :httpc.request("https://raw.githubusercontent.com/chrzaszcz/" <> p); tp = "/tmp/" <> Path.basename(p); File.write!(tp, src); c tp end; import ExDoctor; :tr.start
```

This snippet downloads, compiles and starts two modules:

- [`:tr`](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html) is the main module of [Erlang Doctor](https://hex.pm/packages/erlang_doctor), which provides all the functionality.
- `ExDoctor` is a small Elixir module, which allows using the Erlang records defined in `tr.hrl`.

The Erlang records are used to allow quick and easy pattern-matching, which is used very frequently in ExDoctor.
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
    {:ex_doctor, "~> 0.3.1"}
  ]
end
```

### Use it during development

You can make Erlang Doctor available in `iex` by cloning it to `EX_DOCTOR_PATH`,
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

In our case ExDoctor is automatically started by `mix`, but if you need to start it yourself, call `:tr.start/0`.

There is also `:tr.start/1`, which accepts a [map of options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:init_options/0), including:

- `tab`: collected traces are stored in an ETS table with this name (default: `:trace`),
- `limit`: maximum number of traces in the table - when it is reached, tracing is stopped (default: no limit).

There are `:tr.start_link/0` and `:tr.start_link/1` as well, and they are intended for use with the whole application.

### Tracing with `trace`

Let's set up an alias for the `Example` module, because it will be used very often:

```elixir
iex(1)> alias ExDoctor.Example
ExDoctor.Example
```

To trace function calls for given modules, use `:tr.trace/1`, providing a list of traced modules:

```elixir
iex(2)> :tr.trace([Example])
:ok
```

You can provide `{module, function, arity}` tuples in the list as well.
The function `:tr.trace_app/1` traces an application, and `:tr.trace_apps/1` traces multiple ones.

If you need to trace an application and some additional modules, use `:tr.app_modules/1` to get the list of modules for an application:

```elixir
:tr.trace([Module1, Module2 | :tr.app_modules(:your_app)])
```

If you want to trace selected processes instead of all of them, you can use
`:tr.trace/2`:

```elixir
:tr.trace([Module1, Module2], [Pid1, Pid2])
```

The `:tr.trace/1` function also accepts a [map of options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:trace_options/0), which include:

- `modules`: a list of module names or `{module, function, arity}` tuples. The list is empty by default.
- `pids`: a list of Pids of processes to trace, or `:all` (default) to trace all processes.
- `msg`: `:none` (default), `:all`, `:send` or `:recv`. Specifies which message events will be traced. By default no messages are traced.
- `msg_trigger`: `:after_traced_call` (default) or `:always`. By default, traced messages in each process are stored after the first traced function call in that process. The goal is to limit the number of traced messages, which can be huge in the entire Erlang system. If you want all messages, set it to `:always`.

This means that `:tr.trace(modules, pids)` is a shortcut for `:tr.trace(%{modules: modules, pids: pids})`,
and `:tr.trace(modules)` is a shortcut for `:tr.trace(%{modules: modules})`.

### Calling the traced function

Now we can call some functions - let's trace the following function call.
It calculates the factorial recursively and sleeps 1 ms between each step.

```elixir
iex(3)> Example.sleepy_factorial(3)
6
```

### Stopping tracing

You can stop tracing with `:tr.stop_tracing/0`:

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
They are stored as [`tr`](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:tr/0) records with the following fields:

- `index`: trace identifier, auto-incremented for each received trace.
- `pid`: process ID associated with the trace.
- `event`: `:call`, `:return` or `:exception` for function traces; `:send` or `:recv` for messages.
- `mfa`: `{module, function, arity}` for function traces; `:no_mfa` for messages.
- `data`: argument list (for calls), returned value (for returns) or class and value (for exceptions).
- `timestamp` in microseconds.
- `info`: For `:send` events it is a `{to, exists}` tuple, where `to` is the recipient pid, and `exists` is a boolean indicating if the recipient process existed. For other events it is `:no_info`.

You can load the record definitions with `import ExDoctor`:

```elixir
iex(5)> import ExDoctor
ExDoctor
```

### Trace selection: `select`

Use `:tr.select/0` to select all collected traces, which include a system call to `__info__/1`
followed by the call to `sleepy_factorial/1`.

```elixir
iex(6)> :tr.select()
[
  {:tr, 1, #PID<0.187.0>, :call, {ExDoctor.Example, :__info__, 1},
   [:deprecated], 1705413018330494, :no_info},
  {:tr, 2, #PID<0.187.0>, :return, {ExDoctor.Example, :__info__, 1}, [],
   1705413018330501, :no_info},
  {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [3],
   1705413018330532, :no_info},
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :no_info},
  {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [1],
   1705413018334514, :no_info},
  {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [0],
   1705413018336506, :no_info},
  {:tr, 7, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 1,
   1705413018338509, :no_info},
  {:tr, 8, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 1,
   1705413018338511, :no_info},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :no_info},
  {:tr, 10, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 6,
   1705413018338513, :no_info}
]
```

The `:tr.select/1` function accepts a fun that is passed to `:ets.fun2ms/1`.
This way you can limit the selection to specific items and select only some fields from the [`tr`](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:tr/0) record:

```elixir
iex(7)> :tr.select(fn tr(event: :call, data: [n]) when is_integer(n) -> n end)
[3, 2, 1, 0]
```

Use `:tr.select/2` to further filter the results by searching for a term in the `data` field
(recursively searching in lists, tuples and maps).

```elixir
iex(8)> :tr.select(fn t -> t end, 2)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :no_info},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :no_info}
]
```

### Trace filtering: `filter`

Sometimes it might be easier to use `:tr.filter/1`, because it can accept any function as the argument.
You can use `:tr.contains_data/2` to search for a term like in the example above.

```elixir
iex(9)> traces = :tr.filter(fn t -> :tr.contains_data(2, t) end)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :no_info},
  {:tr, 9, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1}, 2,
   1705413018338512, :no_info}
]
```

The provided function is a predicate, which has to return `true` for the matching traces.
For other traces it can return another value, or even raise an exception:

```elixir
iex(10)> :tr.filter(fn tr(data: [2]) -> true end)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :no_info}
]
```

There is also `:tr.filter/2`, which can be used to search in a different table than the current one - or in a list:

```elixir
iex(11)> :tr.filter(fn tr(event: :call) -> true end, traces)
[
  {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
   1705413018332522, :no_info}
]
```

There are also additional ready-to-use predicates besides `:tr.contains_data/2`:

1. `:tr.match_data/2` performs a recursive check for terms like `:tr.contains_data/2`,
  but instead of checking for equality, it applies the predicate function
  provided as the first argument to each term, and returns `true` if the predicate returned `true`
  for any of them. The predicate can return any other value or fail for non-matching terms.
1. `:tr.contains_val/2` is like `:tr.contains_data/2`, but the second argument is the `data` term itself rather than a trace record with data.
2. `:tr.match_val/2` is like `:tr.match_data/2`, but the second argument is the `data` term itself rather than a trace record with data.

By combining these predicates, you can search for complex terms, e.g.
the following expression returns trace records that contain any (possibly nested in tuples/lists/maps)
3-element tuples with a map as the third element - and that map has to contain the atom `:error`
(possibly nested in tuples/lists/maps).


```elixir
:tr.filter(fn t -> :tr.match_data(fn {_, _, map = %{}} -> :tr.contains_val(:error, map) end, t) end)
```

### Tracebacks for filtered traces: `tracebacks`

To find the tracebacks (stack traces) for matching traces, use `:tr.tracebacks/1`:

```elixir
iex(12)> :tr.tracebacks(fn tr(data: 1) -> true end)
[
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :no_info},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :no_info},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :no_info}
  ]
]
```

Note, that by specifying `data: 1` we are only matching return traces, as call traces always have a list in `data`.
Only one traceback is returned. It starts with a call that returned `1`. What follows is the stack trace for this call.

One can notice that the call for 0 also returned 1, but the call tree got pruned - whenever two tracebacks overlap, only the shorter one is left.
You can change this by returning tracebacks for all matching traces even if they overlap, setting the `output` option to `:all`. Options are specified in the second argument, which is a map:

```elixir
iex(13)> :tr.tracebacks(fn tr(data: 1) -> true end, %{output: :all})
[
  [
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :no_info},
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :no_info},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :no_info},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :no_info}
  ],
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :no_info},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :no_info},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :no_info}
  ]
]
```

The third possibility is `:longest`, which does the opposite of pruning, leaving only the longest tracabacks when they overlap:

```elixir
iex(14)> :tr.tracebacks(fn tr(data: 1) -> true end, %{output: :longest})
[
  [
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :no_info},
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :no_info},
    {:tr, 4, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [2], 1705413018332522, :no_info},
    {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [3], 1705413018330532, :no_info}
  ]
]
```

Possible [options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:tb_options/0) for `:tr.tracebacks/2` include:

- `tab` is the table or list, which is like the second argument of `:tr.filter/2`.
- `output` - `:shortest` (default), `:all`, `:longest` - see above.
- `format` - `:list` (default), `:tree` - returns a list of (possibly merged) call trees instead tracebacks, `:root` - returns a list of root calls. Trees don't distinguish between `:all` and `:longest` output formats. Using `:root` is equivalent to using `:tree`, and then calling `:tr.roots/1` on the results. There is also `:tr.root/1` for a single tree.
- `order` - `:top_down` (default), `:bottom_up` - call order in each tracaback; only for the `:list` format.
- `limit` - positive integer or `:infinity` (default) - limits the number of matched traces. The actual number of tracebacks returned can be smaller unless `output` is set ot `:all`.

There are also functions `:tr.traceback/1` and `:tr.traceback/2`. They set `limit` to one and return only one trace if it exists. The options for `:tr.traceback/2` are the same as for `:tr.traceback/2` except `limit` and `format` (which are not supported). Additionally, it is possible to pass a [`tr`](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:tr/0) record (or an index) as the first argument to `:tr.traceback/1` or `:tr.traceback/2` to obtain the traceback for the provided trace event.

### Trace ranges for filtered traces: `ranges`

To get a list of traces between each matching call and the corresponding return, use `:tr.ranges/1`:

```elixir
iex(15)> :tr.ranges(fn tr(data: [1]) -> true end)
[
  [
    {:tr, 5, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [1], 1705413018334514, :no_info},
    {:tr, 6, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1},
     [0], 1705413018336506, :no_info},
    {:tr, 7, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1},
     1, 1705413018338509, :no_info},
    {:tr, 8, #PID<0.187.0>, :return, {ExDoctor.Example, :sleepy_factorial, 1},
     1, 1705413018338511, :no_info}
  ]
]
```

There is also `:tr.ranges/2` - it accepts a [map of options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:range_options/0), including:

- `tab` is the table or list which is like the second argument of `:tr.filter/2`,
- `max_depth` is the maximum depth of nested calls. A message event also adds 1 to the depth.
    You can set it to 1 to get only the top-level call and the corresponding return.
- `output` - `:all` (default), `:complete` or `:incomplete` - decides whether the output should contain
    complete and/or incomplete ranges. A range is complete if the root call has a return.
    For example, you can use `%{output: :incomplete}` to see only the traces with missing returns.

When you combine the options into `%{output: :incomplete, max_depth: 1}`,
you get all the calls which didn't return (they were still executing when tracing was stopped).

There are two additional functions: `:tr.range/1` and `:tr.range/2`, which return only one range if it exists. It is possible to pass a [`tr`](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:tr/0) record or an index as the first argument to `:tr.range/1` or `:tr.range/2` as well.

### Calling function from a trace: `do`

It is easy to replay a particular function call with `:tr.do/1`:

```elixir
iex(16)> [t] = :tr.filter(fn tr(data: [3]) -> true end)
[
  {:tr, 3, #PID<0.187.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [3],
   1705413018330532, :no_info}
]
iex(17)> :tr.do(t)
6
```

This is useful e.g. for checking if a bug has been fixed without running the whole test suite.
This function can be called with an index as the argument.

### Browsing traces: `lookup`, `prev`, `next`

Use `:tr.lookup/1` to obtain the trace record for an index. Also, given a trace record or an index,
you can obtain the next trace record with `:tr.next/1`, or the previous one with `:tr.prev/1`.

```elixir
iex(18)> t = :tr.next(t)
{:tr, 4, #PID<0.182.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [2],
 1761670163922507, :no_info}
iex(19)> t = :tr.prev(t)
{:tr, 3, #PID<0.182.0>, :call, {ExDoctor.Example, :sleepy_factorial, 1}, [3],
 1761670163920752, :no_info}
```

When there is no trace to return, the `:not_found` error is raised:

```elixir
iex(20)> :tr.prev(1)
** (ErlangError) Erlang error: :not_found
    (erlang_doctor 0.2.9) /Users/pawelchrzaszcz/dev/erlang_doctor/src/tr.erl:629: :tr.prev(1, #Function<15.11954083/1 in :tr.prev/2>, :trace)
    iex:53: (file)
```

There are also more advanced variants of these fucntions: `:tr.next/2` and `:tr.prev/2`.
As their second argument, they take a [map of options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:prev_next_options/0), including:

- `tab` is the table or list (like the second argument of `:tr.filter/2`),
- `pred` is a predicate function that should return `true` for a matching trace record.
    For other arguments, it can return a different value or fail.
    When used, `tab` will be traversed until a matching trace is found.

There are also functions `:tr.seq_next/1` and `:tr.seq_prev/1`.
Given a trace record or an index, they first check the `pid` of the process for that trace record,
and then they return next/previous trace record with the same `pid`.
This effect could be achieved with a predicate function: `fn tr(pid: p) -> p == pid end`,
but these utility functions are much more handy.

## Profiling

You can quickly get a hint about possible bottlenecks and redundancies in your system with function call statistics.

### Call statistics: `call_stat`

The argument of `:tr.call_stat/1` is a function that returns a key by which the traces are grouped.
The simplest way to use this function is to look at the total number of calls and their time.
To do this, we group all calls under one key, e.g. `total`:

```elixir
iex(21)> :tr.call_stat(fn _ -> :total end)
%{total: {5, 7988, 7988}}
```

Values of the returned map have the following format (time is in microseconds):

```{call_count, acc_time, own_time}```

In the example there are four calls, which took 7981 microseconds in total.
For nested calls we only take into account the outermost call, so this means that the whole calculation took 7.981 ms.
Let's see how this looks like for individual steps - we can group the stats by the function argument:

```elixir
iex(22)> :tr.call_stat(fn tr(data: [n]) -> n end)
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
iex(23)> :tr.call_stat(fn tr(data: [n]) when is_integer(n) -> n end)
%{
  0 => {1, 2003, 2003},
  1 => {1, 3997, 1994},
  2 => {1, 5990, 1993},
  3 => {1, 7981, 1991}
}
```

### Sorted call statistics: `sorted_call_stat`

You can sort the call stat by accumulated time (descending) with `:tr.sorted_call_stat/1`:

```elixir
iex(24)> :tr.sorted_call_stat(fn tr(data: [n]) when is_integer(n) -> n end)
[{3, 1, 7981, 1991}, {2, 1, 5990, 1993}, {1, 1, 3997, 1994}, {0, 1, 2003, 2003}]
```

The first element of each tuple is the key, the rest are the same as above.
To pretty-print it, use `:tr.print_sorted_call_stat/2`.
The second argument limits the table row number, e.g. we can only print the top 3 items:

```elixir
iex(25)> :tr.print_sorted_call_stat(fn tr(data: [n]) when is_integer(n) -> n end, 3)
3  1  7981  1991
2  1  5990  1993
1  1  3997  1994
:ok
```

### Call tree statistics: `top_call_trees`

The function `:tr.top_call_trees/0` makes it possible to detect complete call trees that repeat several times,
where corresponding function calls and returns have the same arguments and return values, respectively.
When such functions take a lot of time and do not have useful side effects, they can be often optimized.

As an example, let's trace the call to a function which calculates the 4th element of the Fibonacci Sequence
in a recursive way. The `trace` table should be empty, so let's clean it up first:

```elixir
iex(26)> :tr.clean()
:ok
iex(27)> :tr.trace([{Example, :fib, 1}])
ok
iex(28)> Example.fib(4)
3
iex(29)> :tr.stop_tracing()
:ok
```

Now it is possible to print the most time consuming call trees that repeat at least twice:

```elixir
iex(30)> :tr.top_call_trees()
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

There is also `:tr.top_call_trees/1`, which takes a [map of options](https://hexdocs.pm/erlang_doctor/0.3.1/tr.html#t:top_call_trees_options/0), including:
- `output` - `:reduced` by default, but it can be set to `:complete` where subtrees of already listed trees are also listed.
- `min_count` - minimum number of times a tree has to occur to be listed, the default is 2.
- `min_time` - minimum accumulated time for a tree, by default there is no minimum.
- `max_size` - maximum number of trees presented, the default is 10.

As an exercise, try calling `:tr.top_call_trees(%{min_count: 1000})` for `fib(20)`.

## Exporting and importing traces

To get the current table name, use `:tr.tab/0`:

```elixir
iex(31)> :tr.tab()
:trace
```

To switch to a new table, use `:tr.set_tab/1`. The table need not exist.

```elixir
iex(32)> :tr.set_tab(:tmp)
:ok
```

Now you can collect traces to the new table without changing the original one.

```elixir
iex(33)> :tr.trace([Enum]); Enum.to_list(1..10); :tr.stop_tracing()
:ok
iex(34)> :tr.select()
[
  (...)
]
```

You can dump the current table to file:

```elixir
iex(35)> :tr.dump("tmp.ets")
:ok
```

In a new `iex` session we can load the data with `:tr.load/1`. This will set the current table name to `:tmp`.

```elixir
iex(1)> :tr.load("tmp.ets")
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
