defmodule ExDoctor.Example do
  @moduledoc """
  This module contains sample functions that you can trace with `ExDoctor`.
  """

  @sleep 1

  @doc "Calculates factorial of `n` with a delay of 1 ms after each step"
  def sleepy_factorial(n) when n > 0 do
    :timer.sleep(@sleep)
    n * sleepy_factorial(n - 1)
  end

  def sleepy_factorial(0) do
    :timer.sleep(@sleep)
    1
  end

  @doc """
  Calculates the `n`-th term of the Fibonacci sequence.

  This recursive implementation is suboptimal on purpose.
  The goal is to have a function with extensive redundant branching.
  """
  def fib(n) when n > 1 do
    fib(n - 1) + fib(n - 2)
  end

  def fib(1) do
    1
  end

  def fib(0) do
    0
  end
end
