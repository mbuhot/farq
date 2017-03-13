defmodule Farq.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

 def init(opts) do
   repo = Keyword.fetch!(opts, :repo)
   app = Keyword.fetch!(opts, :app)
   queue = Keyword.fetch!(opts, :queue)
   workers = Keyword.fetch!(opts, :workers)

   pg_config = Application.get_env(app, repo)
   listener_name = Farq.Queue.listener(queue)
   notification_worker = worker(Postgrex.Notifications, [pg_config ++ [name: listener_name]])

   job_workers = for i <- 1 .. workers do
     worker(Farq.Worker, [repo, queue], id: "#{queue}.worker.#{i}")
   end

   supervise([notification_worker | job_workers], strategy: :one_for_one)
 end

end
