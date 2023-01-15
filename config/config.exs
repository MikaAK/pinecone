import Config

config :pinecone,
  project_name: System.get_env("PINECONE_PROJECT_NAME"),
  api_key: System.get_env("PINECONE_API_KEY"),
  environment: System.get_env("PINECONE_CLOUD_ENVIRONMENT")
