defmodule Pinecone.Http do
  @moduledoc false

  def get(endpoint, config \\ []) do
    endpoint
    |> url(config[:environment])
    |> Req.get(headers: headers(config[:api_key]))
    |> parse_response()
  end

  def post(endpoint, body, config \\ []) do
    endpoint
    |> url(config[:environment])
    |> Req.post(body: Jason.encode!(body), headers: headers(config[:api_key]))
    |> parse_response()
  end

  def delete(endpoint, config \\ []) do
    endpoint
    |> url(config[:environment])
    |> then(&Req.request(url: &1, method: :delete, headers: headers(config[:api_key])))
    |> parse_response()
  end

  def patch(endpoint, body, config \\ []) do
    endpoint
    |> url(config[:environment])
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

  defp url(endpoint, env) do
    env =
      if env do
        env
      else
        Pinecone.Config.environment()
      end

    "https://controller.#{env}.pinecone.io/#{endpoint}"
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
