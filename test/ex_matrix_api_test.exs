defmodule ExMatrixApiTest do
  use ExUnit.Case
  doctest ExMatrixApi

  test "greets the world" do
    assert ExMatrixApi.hello() == :world
  end
end
