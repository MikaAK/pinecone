defmodule Pinecone do
  @moduledoc """
  Elixir client for the [Pinecone](https://pinecone.io) REST API.
  """
  import Pinecone.Http

  @type success_t(inner) :: {:ok, inner}
  @type error_t :: {:error, String.t()}

  ## General Operations

  @doc """
  Retrieves Pinecone project name.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec whoami(opts :: keyword()) :: success_t(map()) | error_t()
  def whoami(opts \\ []) do
    Keyword.validate!(opts, [:config])
    get("actions/whoami", opts[:config])
  end

  ## Index Operations

  @doc """
  List all Pinecone indices.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec list_indices(opts :: keyword()) :: success_t(list()) | error_t()
  def list_indices(opts \\ []) do
    Keyword.validate!(opts, [:config])
    get("databases", opts[:config])
  end

  @doc """
  Describe the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec describe_index(index_name :: String.t(), opts :: keyword()) ::
          success_t(map()) | error_t()
  def describe_index(index_name, opts \\ []) do
    Keyword.validate!(opts, [:config])
    get("databases/#{index_name}", opts[:config])
  end

  @valid_metric_types [:euclidean, :cosine, :dotproduct]
  @valid_pod_types [:s1, :p1, :p2]
  @valid_pod_sizes [:x1, :x2, :x4, :x8]
  @valid_pods List.flatten(
                for type <- @valid_pod_types, do: for(size <- @valid_pod_sizes, do: {type, size})
              )

  @doc """
  Creates a Pinecone index with the given name and options.

  ## Options

    * `:dimension` - dimensionality of the index. Defaults to 384

    * `:metric` - distance metric of the index. Defaults to :euclidean.

    * `:pods` - number of pods to use for the index. Defaults to 1

    * `:replicas` - number of replicas to use for the index. Defaults to
      1

    * `:shards` - number of shards to use for the index. Defaults to
      1

    * `:pod_type` - pod type. A tuple of {type, size} where type is one
      of `:s1`, :s2`, or `:p2` and size is one of `:x1`, `:x2`, `:x4`, or
      `:x8`. Defaults to `{:p1, :x1}`

    * `:metadata` - metadata fields to index. Defaults to `[]`

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec create_index(index_name :: String.t(), opts :: keyword()) ::
          success_t(String.t()) | error_t()
  def create_index(index_name, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :config,
        dimension: 384,
        metric: :euclidean,
        pods: 1,
        replicas: 1,
        shards: 1,
        pod_type: {:p1, :x1},
        metadata: []
      ])

    validate!("index_name", index_name, :binary)
    validate!("dimension", opts[:dimension], :non_negative_integer)
    validate!("pods", opts[:pods], :non_negative_integer)
    validate!("replicas", opts[:replicas], :non_negative_integer)
    validate!("shards", opts[:shards], :non_negative_integer)
    validate!("metric", opts[:metric], :one_of, @valid_metric_types)
    validate!("pod_type", opts[:pod_type], :one_of, @valid_pods)
    # TODO: validate metadata

    body = %{
      "name" => index_name,
      "dimension" => opts[:dimension],
      "metric" => Atom.to_string(opts[:metric]),
      "pods" => opts[:pods],
      "replicas" => opts[:replicas],
      "shards" => opts[:shards],
      "pod_type" => to_pod_type(opts[:pod_type])
    }

    post("databases", body, opts[:config])
  end

  @doc """
  Deletes the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec delete_index(index_name :: String.t(), opts :: keyword()) ::
          success_t(String.t()) | error_t()
  def delete_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    delete("databases/#{index_name}", opts[:config])
  end

  @doc """
  Configures the given Pinecone index with the given options.

  ## Options

    * `:replicas` - number of replicas to use for the index. Defaults to
      1

    * `:pod_type` - pod type. A tuple of {type, size} where type is one
      of `:s1`, :s2`, or `:p2` and size is one of `:x1`, `:x2`, `:x4`, or
      `:x8`. Defaults to `{:p1, :x1}`

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec configure_index(index_name :: String.t(), opts :: keyword()) ::
          success_t(String.t()) | error_t()
  def configure_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, pod_type: {:p1, :x1}, replicas: 1])

    validate!("replicas", opts[:replicas], :non_negative_integer)
    validate!("pod_type", opts[:pod_type], :one_of, @valid_pods)

    body = %{
      "replicas" => opts[:replicas],
      "pod_type" => to_pod_type(opts[:pod_type])
    }

    patch("databases/#{index_name}", body, opts[:config])
  end

  defp to_pod_type({type, size}), do: "#{Atom.to_string(type)}.#{Atom.to_string(size)}"

  defp validate!(_key, value, :binary) when is_binary(value), do: :ok

  defp validate!(key, value, :binary) do
    raise ArgumentError, "expected #{key} to be a binary, got #{inspect(value)}"
  end

  defp validate!(_key, value, :non_negative_integer) when is_integer(value) and value > 0, do: :ok

  defp validate!(key, value, :non_negative_integer) do
    raise ArgumentError, "expected #{key} to be a non-negative integer, got #{inspect(value)}"
  end

  defp validate!(key, value, :one_of, values) do
    if value in values do
      :ok
    else
      raise ArgumentError,
            "expected #{key} to be one of #{inspect(values)}, got #{inspect(value)}"
    end
  end
end
