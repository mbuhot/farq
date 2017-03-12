use Mix.Config

# config :pgjob, key: :value
# In your config/config.exs file
config :pgjob, ecto_repos: [Pgjob.Repo]

config :pgjob, Pgjob.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "pgjob",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: "5432"

config :logger, level: :info
