defmodule Pinecone.Index do
  @moduledoc """
  Wrapper around a Pinecone index.
  """

  defstruct [:name, :project_name]

  @type t :: %__MODULE__{
          name: String.t(),
          project_name: String.t()
        }
end
