defmodule Pinecone do
  @moduledoc """
  Elixir client for the [Pinecone](https://pinecone.io) REST API.
  """
  import Pinecone.Http

  alias Pinecone.Index

  @type success_type(inner) :: {:ok, inner}
  @type error_type :: {:error, String.t()}
  @type index_type :: %Index{name: String.t(), project_name: String.t()}

  ## General Operations

  @doc """
  Retrieves Pinecone project name.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec whoami(opts :: keyword()) :: success_type(map()) | error_type()
  def whoami(opts \\ []) do
    opts = Keyword.validate!(opts, [:config])
    get(:indices, "actions/whoami", opts[:config])
  end

  ## Index Operations

  @doc """
  Constructs a Pinecone index struct for use in vector operations.

  ## Options

    * `:project_name` - project name to use to override application
      configuration. Defaults to `nil`
  """
  def index(index_name, opts \\ []) when is_binary(index_name) do
    opts = Keyword.validate!(opts, [:project_name])
    project_name = opts[:project_name] || Pinecone.Config.project_name()
    %Index{name: index_name, project_name: project_name}
  end

  @doc """
  List all Pinecone indices.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec list_indices(opts :: keyword()) :: success_type(list()) | error_type()
  def list_indices(opts \\ []) do
    opts = Keyword.validate!(opts, [:config])
    get(:indices, "databases", opts[:config])
  end

  @doc """
  Describe the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec describe_index(index_name :: String.t(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])
    get(:indices, "databases/#{index_name}", opts[:config])
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
          success_type(String.t()) | error_type()
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

    post(:indices, "databases", body, opts[:config])
  end

  @doc """
  Deletes the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec delete_index(index_name :: String.t(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    delete(:indices, "databases/#{index_name}", opts[:config])
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
          success_type(String.t()) | error_type()
  def configure_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, pod_type: {:p1, :x1}, replicas: 1])

    validate!("replicas", opts[:replicas], :non_negative_integer)
    validate!("pod_type", opts[:pod_type], :one_of, @valid_pods)

    body = %{
      "replicas" => opts[:replicas],
      "pod_type" => to_pod_type(opts[:pod_type])
    }

    patch(:indices, "databases/#{index_name}", body, opts[:config])
  end

  ## Vector operations

  @doc """
  Describes vector statistics of the given index.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec describe_index_stats(index :: index_type(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_index_stats(%Index{name: name, project_name: project_name}, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    get({:vectors, "#{name}-#{project_name}"}, "describe_index_stats", opts[:config])
  end

  @doc """
  Upserts a vectors into the given Pinecone index.

  For upserts with greater than 100 vectors, you should batch the upsert
  into multipe asynchronous requests:

      vectors
      |> Stream.chunk_every(100)
      |> Enum.map(&Task.async(fn -> Pinecone.upsert(index, &1) end))
      |> Enum.map(&Task.await(&1))

  ## Options

    * `:namespace` - index namespace to upsert vectors to. Defaults to `nil`
      which will upsert vectors in the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec upsert_vectors(index :: index_type(), vectors :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def upsert_vectors(%Index{name: name, project_name: project_name}, vectors, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    body = %{"vectors" => List.wrap(vectors)}

    body =
      if opts[:namespace] do
        validate!("namespace", opts[:namespace], :binary)
        Map.put(body, "namespace", opts[:namespace])
      else
        body
      end

    post({:vectors, "#{name}-#{project_name}"}, "vectors/upsert", body, opts[:config])
  end

  @doc """
  Fetches vectors with the given IDs from the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec fetch_vectors(index :: index_type(), ids :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def fetch_vectors(%Index{name: name, project_name: project_name}, ids, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    ids = Enum.map(ids, &{"ids", &1})

    get({:vectors, "#{name}-#{project_name}"}, "vectors/fetch", opts[:config], params: ids)
  end

  @doc """
  Deletes vectors with the given IDs from the given Pinecone index.

  ## Options

    * `:namespace` - index namespace to delete vectors from. Defaults to `nil`
      which will delete vectors from the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec delete_vectors(index :: index_type(), ids :: list(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_vectors(%Index{name: name, project_name: project_name}, ids, opts \\ [])
      when is_list(ids) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    params = Enum.map(ids, &{"ids", &1})
    params = if opts[:namespace], do: [{"namespace", opts[:namespace]} | params], else: params

    delete({:vectors, "#{name}-#{project_name}"}, "vectors/delete", opts[:config], params: params)
  end

  @doc """
  Deletes all vectors from the given Pinecone index.

  ## Options

    * `:namespace` - index namespace to delete vectors from. Defaults to `nil`
      which will delete all vectors from the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec delete_all_vectors(index :: index_type(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_all_vectors(%Index{name: name, project_name: project_name}, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    params = [{"delete_all", true}]
    params = if opts[:namespace], do: [{"namespace", opts[:namespace]} | params], else: params

    delete({:vectors, "#{name}-#{project_name}"}, "vectors/delete", opts[:config], params: params)
  end

  @doc """
  Queries the given Pinecone index with the given vector.

  ## Options

    * `:top_k` - return the top-k vectors from the index. Defaults to
      `5`

    * `:include_values` - return vector values with results. Defaults to
      `false`

    * `:include_metadata` - return vector metadata with results. Defaults
      to `false`

    * `:namespace` - index namespace to query. Defaults to `nil`
      which will query vectors in the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec query(index :: index_type(), vector :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def query(%Index{name: name, project_name: project_name}, vector, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :config,
        :namespace,
        top_k: 5,
        include_values: false,
        include_metadata: false
      ])

    validate!("top_k", opts[:top_k], :non_negative_integer)
    validate!("include_values", opts[:include_values], :boolean)
    validate!("include_metadata", opts[:include_metadata], :boolean)

    body = %{
      "vector" => vector,
      "topK" => opts[:top_k],
      "includeValues" => opts[:include_values],
      "includeMetadata" => opts[:include_metadata]
    }

    body = if opts[:namespace], do: Map.put(body, "namespace", opts[:namespace]), else: body

    post({:vectors, "#{name}-#{project_name}"}, "query", body, opts[:config])
  end

  ## Collection Operations

  @doc """
  Creates a Pinecone collection with the given name from the given
  Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec create_collection(
          collection_name :: String.t(),
          index_name :: String.t(),
          opts :: keyword()
        ) :: success_type(String.t()) | error_type()
  def create_collection(collection_name, index_name, opts \\ [])
      when is_binary(collection_name) and is_binary(index_name) do
    opts = Keyword.validate!(opts, [:config])

    body = %{
      "name" => collection_name,
      "source" => index_name
    }

    post(:collections, "collections", body, opts[:config])
  end

  @doc """
  Describes the given Pinecone collection.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec describe_collection(collection_name :: String.t(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_collection(collection_name, opts \\ []) when is_binary(collection_name) do
    opts = Keyword.validate!(opts, [:config])

    get(:collections, "collections/#{collection_name}", opts[:config])
  end

  @doc """
  Lists all Pinecone collections.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec list_collections(opts :: keyword()) :: success_type(list()) | error_type()
  def list_collections(opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    get(:collections, "collections", opts[:config])
  end

  @doc """
  Deletes the given Pinecone collection.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec delete_collection(collection_name :: String.t(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_collection(collection_name, opts \\ []) when is_binary(collection_name) do
    opts = Keyword.validate!(opts, [:config])

    get(:collections, "collections/#{collection_name}", opts[:config])
  end

  defp to_pod_type({type, size}), do: "#{Atom.to_string(type)}.#{Atom.to_string(size)}"

  defp validate!(_key, value, :non_negative_integer) when is_integer(value) and value > 0, do: :ok
  defp validate!(_key, value, :boolean) when is_boolean(value), do: :ok
  defp validate!(_key, value, :binary) when is_binary(value), do: :ok

  defp validate!(key, value, type) do
    raise ArgumentError, "expected #{key} to be type #{inspect(type)}, got #{inspect(value)}"
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
