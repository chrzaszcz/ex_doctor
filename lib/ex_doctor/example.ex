defmodule ExDoctor.Example do
  @sleep 100

  def sleepy_factorial(n) when n > 0 do
    :timer.sleep(@sleep)
    n * sleepy_factorial(n - 1)
  end

  def sleepy_factorial(0) do
    :timer.sleep(@sleep)
    1
  end
end
