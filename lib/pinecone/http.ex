defmodule Pinecone.Http do
  @moduledoc false

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
    |> then(
      &Req.request(url: &1, params: params, method: :delete, headers: headers(config[:api_key]))
    )
    |> parse_response()
  end

  def patch(type, endpoint, body, config \\ []) do
    type
    |> url(endpoint, config[:environment])
    |> then(
      &Req.request(
        url: &1,
        body: Jason.encode!(body),
        method: :patch,
        headers: headers(config[:api_key])
      )
    )
    |> parse_response()
  end

  defp parse_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %{body: body}}) do
    {:error, body}
  end

  defp url(type, endpoint, env) when type in [:indices, :collections] do
    env =
      if env do
        env
      else
        Pinecone.Config.environment()
      end

    "https://controller.#{env}.pinecone.io/#{endpoint}"
  end

  defp url({:vectors, slug}, endpoint, env) do
    env =
      if env do
        env
      else
        Pinecone.Config.environment()
      end

    "https://#{slug}.svc.#{env}.pinecone.io/#{endpoint}"
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
