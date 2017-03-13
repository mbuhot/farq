defmodule Farq.Worker do
  require Logger

  def start_link(repo, queue) do
    {:ok, spawn_link(__MODULE__, :loop, [repo, queue])}
  end

  def loop(repo, queue) do
    case work_job(repo, queue) do
      {:ok, :done} -> Farq.Queue.wait(queue, 30_000)
      {:ok, :continue} -> :ok
      error -> Logger.error(inspect(error))
    end
    loop(repo, queue)
  end

  def work_job(repo, queue) do
    repo.transaction fn ->
      case Farq.Queue.dequeue(repo, queue) do
        nil ->
          :done
        %{"module" => m, "function" => f, "args" => a} ->
          work_job(m |> String.to_atom, f |> String.to_atom, a)
          :continue
      end
    end
  end

  def work_job(module, function, args) do
    apply(module, function, args)
  rescue
    e -> Logger.error(inspect(e))
  end

end
