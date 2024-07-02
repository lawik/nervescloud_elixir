defmodule NcTest do
  use ExUnit.Case
  doctest Nc

  test "greets the world" do
    assert Nc.hello() == :world
  end
end
