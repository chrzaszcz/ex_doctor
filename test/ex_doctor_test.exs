defmodule ExDoctorTest do
  use ExUnit.Case
  doctest ExDoctor

  test "greets the world" do
    assert ExDoctor.hello() == :world
  end
end
