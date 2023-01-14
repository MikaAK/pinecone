import Config

config :pinecone,
  api_key: System.get_env("PINECONE_API_KEY"),
  environment: System.get_env("PINECONE_CLOUD_ENVIRONMENT")
