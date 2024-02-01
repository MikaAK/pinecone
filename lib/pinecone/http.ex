defmodule Pinecone.HTTP do
  @moduledoc false

  require Logger

  def get(type, endpoint, config \\ [], opts \\ []) do
    params = opts[:params] || []

    type
    |> url(endpoint, config[:environment])
    |> Req.get(params: params, headers: headers(config[:api_key]))
    |> parse_response()
  end

  def post(type, endpoint, body, config \\ []) do
    type
    |> url(endpoint, config[:environment])
    |> Req.post(body: Jason.encode!(body), headers: headers(config[:api_key]))
    |> parse_response()
  end

  def delete(type, endpoint, config \\ [], opts \\ []) do
    params = opts[:params] || []

    type
    |> url(endpoint, config[:environment])
    |> Req.delete(params: params, headers: headers(config[:api_key]))
    |> parse_response()
  end

  def patch(type, endpoint, body, config \\ []) do
    type
    |> url(endpoint, config[:environment])
    |> Req.patch(body: Jason.encode!(body), headers: headers(config[:api_key]))
    |> parse_response()
  end

  defp parse_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %{body: body} = e}) do
    Logger.warning("Failed pinecone request: #{inspect(e)}")

    {:error, body}
  end

  defp parse_response({:error, _reason} = error), do: error

  defp url(:indices, "actions/whoami" = endpoint, env) do
    env =
      if env do
        env
      else
        Pinecone.Config.environment()
      end

    "https://controller.#{env}.pinecone.io/#{endpoint}"
  end

  defp url(:indices, endpoint, _env) do
    Path.join("https://api.pinecone.io/indexes", endpoint)
  end

  defp url(:collections, endpoint, _env) do
    Path.join("https://api.pinecone.io/collections", endpoint)
  end

  defp url({:vectors, host}, endpoint, _env) do
    Path.join("https://#{host}/vectors", endpoint)
  end

  defp headers(api_key) do
    api_key =
      if api_key do
        api_key
      else
        Pinecone.Config.api_key()
      end

    [accept: "application/json", content_type: "application/json", api_key: api_key]
  end
end
