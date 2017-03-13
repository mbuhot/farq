# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :demo, ecto_repos: [Demo.Repo]

config :demo, Demo.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "farq_demo",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: "5432"

config :demo, Demo.Jobs,
  repo: Demo.Repo,
  queue: "jobs",
  workers: 10

config :logger, level: :info
