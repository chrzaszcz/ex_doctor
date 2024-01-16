defmodule ExDoctor.Example do
  @sleep 1

  def sleepy_factorial(n) when n > 0 do
    :timer.sleep(@sleep)
    n * sleepy_factorial(n - 1)
  end

  def sleepy_factorial(0) do
    :timer.sleep(@sleep)
    1
  end

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
