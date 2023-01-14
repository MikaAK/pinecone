defmodule PineconeTest do
  use ExUnit.Case
  doctest Pinecone

  test "greets the world" do
    assert Pinecone.hello() == :world
  end
end
