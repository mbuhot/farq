defmodule Pgjob.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec

  @mixenv Mix.env()

  def start(_type, _args) do
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    Supervisor.start_link(children(@mixenv), strategy: :one_for_one, name: Pgjob.Supervisor)
  end

  def children(:test) do
    [supervisor(Pgjob.Repo, [])]
  end
  def children(_) do
    pg_config = Application.get_env(:pgjob, Pgjob.Repo)
    job_workers = for i <- 1..10, do: worker(Pgjob.Worker, [Pgjob.Repo, "jobs"], id: "Pgjob.Worker.#{i}")

    [
      supervisor(Pgjob.Repo, []),
      worker(Postgrex.Notifications, [pg_config ++ [name: :pgjob_listener]])
    ] ++ job_workers
  end
end
