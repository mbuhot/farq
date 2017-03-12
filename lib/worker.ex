defmodule Pgjob.Worker do
  def start_link(repo, queue) do
    {:ok, spawn_link(__MODULE__, :loop, [repo, queue])}
  end

  def loop(repo, queue) do
    case work_job(repo, queue) do
      {:ok, :done} -> wait_for_notification(queue)
      {:ok, :continue} -> :ok
      error -> IO.inspect(error)
    end
    loop(repo, queue)
  end

  def work_job(repo, queue) do
    repo.transaction fn ->
      case Pgjob.dequeue(repo, queue) do
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
    e -> IO.inspect(e)
  end

  def wait_for_notification(queue) do
    {:ok, ref} = Postgrex.Notifications.listen(:pgjob_listener, queue)
    receive do
      {:notification, _pid, _ref, ^queue, _payload} -> :ok
    after
      30_000 -> :ok
    end
    Postgrex.Notifications.unlisten(:pgjob_listener, ref)
    clear_notifications(queue)
  end

  def clear_notifications(queue) do
    receive do
      {:notification, _pid, _ref, ^queue, _payload} -> clear_notifications(queue)
    after
      0 -> :ok
    end
  end
end
