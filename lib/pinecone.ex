defmodule Pinecone do
  @moduledoc """
  Elixir client for the [Pinecone](https://pinecone.io) REST API.
  """
  alias Pinecone.{Index, HTTP}

  @type success_type(inner) :: {:ok, inner}
  @type error_type :: {:error, String.t()}
  @type index_type :: %Index{name: String.t(), project_name: String.t()}

  ## Index Operations

  @doc """
  Constructs a Pinecone index struct for use in vector operations.

  ## Options

    * `:project_name` - project name to use to override application
      configuration. Defaults to `nil`
  """
  @spec index(String.t(), Keyword.t()) :: Index.t()
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
  @spec list_indices() :: success_type(list(map)) | error_type()
  @spec list_indices(opts :: keyword()) :: success_type(list(map)) | error_type()
  def list_indices(opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    with {:ok, %{"indexes" => indexes}} <- HTTP.get(:indices, "", opts[:config]) do
      {:ok, indexes}
    end
  end

  @doc """
  Describe the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec describe_index(index_name :: String.t()) ::
          success_type(map()) | error_type()
  @spec describe_index(index_name :: String.t(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])
    HTTP.get(:indices, index_name, opts[:config])
  end

  @valid_clouds ["gcp", "aws", "azure"]
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
  @spec create_index(index_name :: String.t()) ::
          success_type(map) | error_type()
  @spec create_index(index_name :: String.t(), opts :: keyword()) ::
          success_type(map) | error_type()
  def create_index(index_name, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :config,
        dimension: 384,
        metric: :euclidean,
        spec: []
      ])

    validate!("index_name", index_name, :binary)
    validate!("dimension", opts[:dimension], :non_negative_integer)
    validate!("metric", opts[:metric], :one_of, @valid_metric_types)

    spec_params = validate_create_index_opts(opts[:spec])

    body = %{
      "name" => index_name,
      "dimension" => opts[:dimension],
      "metric" => Atom.to_string(opts[:metric]),
      "spec" => spec_params
    }

    HTTP.post(:indices, "", body, opts[:config])
  end

  defp validate_create_index_opts(spec_opts) do
    case spec_opts do
      [serverless: serverless_opts] ->
        serverless_opts =
          Keyword.validate!(serverless_opts,
            cloud: "aws",
            region: "us-west-2"
          )

        validate!("cloud", serverless_opts[:cloud], :one_of, @valid_clouds)
        validate!("region", serverless_opts[:region], :binary)

        %{
          "serverless" => %{
            "cloud" => serverless_opts[:cloud],
            "region" => serverless_opts[:region]
          }
        }

      [pod: pod_opts] ->
        pod_opts =
          Keyword.validate!(pod_opts,
            pods: 1,
            replicas: 1,
            shards: 1,
            pod_type: {:p1, :x1},
            metadata: []
          )

        validate!("pods", pod_opts[:pods], :non_negative_integer)
        validate!("replicas", pod_opts[:replicas], :non_negative_integer)
        validate!("shards", pod_opts[:shards], :non_negative_integer)
        validate!("pod_type", pod_opts[:pod_type], :one_of, @valid_pods)

        %{
          "pod" => %{
            "pods" => pod_opts[:pods],
            "replicas" => pod_opts[:replicas],
            "shards" => pod_opts[:shards],
            "pod_type" => to_pod_type(pod_opts[:pod_type])
          }
        }

      _ ->
        raise "Must provide `serverless` or `pod` under the `spec` key when creating indexes"
    end
  end

  @doc """
  Deletes the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
      level configuration. Defaults to `nil`
  """
  @spec delete_index(index_name :: String.t()) ::
          success_type(String.t()) | error_type()
  @spec delete_index(index_name :: String.t(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_index(index_name, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    HTTP.delete(:indices, index_name, opts[:config])
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
  @spec configure_index(index_name :: String.t()) ::
          success_type(String.t()) | error_type()
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

    HTTP.patch(:indices, index_name, body, opts[:config])
  end

  ## Vector operations

  @doc """
  Describes vector statistics of the given index.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec describe_index_stats(index :: index_type()) ::
          success_type(map()) | error_type()
  @spec describe_index_stats(index :: index_type(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_index_stats(%Index{name: name}, opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    get_vector("describe_index_stats", name, opts[:config], params: opts[:params])
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
  @spec upsert_vectors(index :: index_type(), vectors :: list()) ::
          success_type(map()) | error_type()
  @spec upsert_vectors(index :: index_type(), vectors :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def upsert_vectors(%Index{name: name}, vectors, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    body = %{"vectors" => List.wrap(vectors)}

    body =
      if opts[:namespace] do
        validate!("namespace", opts[:namespace], :binary)
        Map.put(body, "namespace", opts[:namespace])
      else
        body
      end

    post_vector("upsert", name, body, opts[:config])
  end

  @doc """
  Fetches vectors with the given IDs from the given Pinecone index.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec fetch_vectors(index :: index_type(), ids :: list()) ::
          success_type(map()) | error_type()
  @spec fetch_vectors(index :: index_type(), ids :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def fetch_vectors(%Index{name: name}, ids, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    ids = Enum.map(ids, &{"ids", &1})

    params = if opts[:namespace], do: [{"namespace", opts[:namespace]} | ids], else: ids

    get_vector("fetch", name, opts[:config], params: params)
  end

  @doc """
  Deletes vectors with the given IDs from the given Pinecone index.

  ## Options

    * `:namespace` - index namespace to delete vectors from. Defaults to `nil`
      which will delete vectors from the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec delete_vectors(index :: index_type(), ids :: list()) ::
          success_type(String.t()) | error_type()
  @spec delete_vectors(index :: index_type(), ids :: list(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_vectors(%Index{name: name}, ids, opts \\ [])
      when is_list(ids) do
    opts = Keyword.validate!(opts, [:config, :namespace])

    params = Enum.map(ids, &{"ids", &1})
    params = if opts[:namespace], do: [{"namespace", opts[:namespace]} | params], else: params

    delete_vector("delete", name, opts[:config], params: params)
  end

  @doc """
  Deletes all vectors from the given Pinecone index.
  If the filter option is passed, deletes only vectors that match the given metadata filter

  ## Options

    * `:namespace` - index namespace to delete vectors from. Defaults to `nil`
      which will delete all vectors from the default namespace

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`

    * `:filter` - metadata filter to apply to the deletion. See https://docs.pinecone.io/docs/metadata-filtering
  """
  @spec delete_all_vectors(index :: index_type()) ::
          success_type(String.t()) | error_type()
  @spec delete_all_vectors(index :: index_type(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_all_vectors(%Index{name: name}, opts \\ []) do
    opts = Keyword.validate!(opts, [:config, :namespace, :filter])

    body =
      if is_map(opts[:filter]),
        do: %{"filter" => opts[:filter]},
        else: %{"deleteAll" => true}

    body = if opts[:namespace], do: Map.put(body, "namespace", opts[:namespace]), else: body

    post_vector("delete", name, body, opts[:config])
  end

  defp delete_vector(path, name, config, opts) do
    with {:ok, host} <- index_host(name) do
      HTTP.delete({:vectors, host}, path, config, opts)
    end
  end

  defp get_vector(path, name, config, opts) do
    with {:ok, host} <- index_host(name) do
      HTTP.get({:vectors, host}, path, config, opts)
    end
  end

  defp post_vector(path, name, body, opts) do
    with {:ok, host} <- index_host(name) do
      HTTP.post({:vectors, host}, path, body, opts)
    end
  end

  defp post_root(path, name, body, opts) do
    with {:ok, host} <- index_host(name) do
      HTTP.post({:root, host}, path, body, opts)
    end
  end

  defp index_host(index_name) do
    with {:ok, %{"host" => host}} <- describe_index(index_name) do
      {:ok, host}
    end
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

    * `:filter` - metadata filter to apply to the query. See https://docs.pinecone.io/docs/metadata-filtering

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec query(index :: index_type(), vector :: list()) ::
          success_type(map()) | error_type()
  @spec query(index :: index_type(), vector :: list(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def query(%Index{name: name}, vector, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :config,
        :namespace,
        top_k: 5,
        include_values: false,
        include_metadata: false,
        filter: %{}
      ])

    validate!("top_k", opts[:top_k], :non_negative_integer)
    validate!("include_values", opts[:include_values], :boolean)
    validate!("include_metadata", opts[:include_metadata], :boolean)
    validate!("filter", opts[:filter], :map)

    body = %{
      "vector" => vector,
      "topK" => opts[:top_k],
      "includeValues" => opts[:include_values],
      "includeMetadata" => opts[:include_metadata],
      "filter" => opts[:filter]
    }

    body = if opts[:namespace], do: Map.put(body, "namespace", opts[:namespace]), else: body

    post_root("query", name, body, opts[:config])
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
  @spec create_collection(
          collection_name :: String.t(),
          index_name :: String.t()
        ) :: success_type(String.t()) | error_type()
  def create_collection(collection_name, index_name, opts \\ [])
      when is_binary(collection_name) and is_binary(index_name) do
    opts = Keyword.validate!(opts, [:config])

    body = %{
      "name" => collection_name,
      "source" => index_name
    }

    HTTP.post(:collections, "", body, opts[:config])
  end

  @doc """
  Describes the given Pinecone collection.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec describe_collection(collection_name :: String.t()) ::
          success_type(map()) | error_type()
  @spec describe_collection(collection_name :: String.t(), opts :: keyword()) ::
          success_type(map()) | error_type()
  def describe_collection(collection_name, opts \\ []) when is_binary(collection_name) do
    opts = Keyword.validate!(opts, [:config])

    HTTP.get(:collections, collection_name, opts[:config])
  end

  @doc """
  Lists all Pinecone collections.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec list_collections() :: success_type(list()) | error_type()
  @spec list_collections(opts :: keyword()) :: success_type(list()) | error_type()
  def list_collections(opts \\ []) do
    opts = Keyword.validate!(opts, [:config])

    HTTP.get(:collections, "", opts[:config])
  end

  @doc """
  Deletes the given Pinecone collection.

  ## Options

    * `:config` - client configuration used to override application
    level configuration. Defaults to `nil`
  """
  @spec delete_collection(collection_name :: String.t()) ::
          success_type(String.t()) | error_type()
  @spec delete_collection(collection_name :: String.t(), opts :: keyword()) ::
          success_type(String.t()) | error_type()
  def delete_collection(collection_name, opts \\ []) when is_binary(collection_name) do
    opts = Keyword.validate!(opts, [:config])

    HTTP.get(:collections, collection_name, opts[:config])
  end

  defp to_pod_type({type, size}), do: "#{Atom.to_string(type)}.#{Atom.to_string(size)}"

  defp validate!(_key, value, :non_negative_integer) when is_integer(value) and value > 0, do: :ok
  defp validate!(_key, value, :boolean) when is_boolean(value), do: :ok
  defp validate!(_key, value, :binary) when is_binary(value), do: :ok
  defp validate!(_key, value, :map) when is_map(value), do: :ok

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
