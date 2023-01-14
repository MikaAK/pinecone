defmodule Pinecone.Config do
  @moduledoc false

  def api_key(), do: Application.get_env(:pinecone, :api_key)

  def environment(), do: Application.get_env(:pinecone, :environment)
end
