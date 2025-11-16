defmodule RouterosApiTest do
  use ExUnit.Case
  doctest RouterosApi

  test "greets the world" do
    assert RouterosApi.hello() == :world
  end
end
