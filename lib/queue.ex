defmodule Farq.Queue do
  defmacro __using__(otp_app: app) do
    quote do
      @otp_app unquote(app)
      @config Application.get_env(@otp_app, __MODULE__)
      @repo @config[:repo]
      @queue @config[:queue]

      def start_link() do
        Farq.Supervisor.start_link([app: @otp_app] ++ @config)
      end

      def enqueue(mod, fun, args) do
        Farq.Queue.enqueue(@repo, @queue, mod, fun, args)
      end

      def dequeue() do
        Farq.Queue.dequeue(@repo, @queue)
      end
    end
  end

  require Ecto.Query, as: Query

  @doc """
  Enqueue a job.
  """
  def enqueue(repo, queue, mod, fun, args) do
    job = %{data: %{module: mod, function: fun, args: args}}
    {1, [%{id: id}]} = repo.insert_all(queue, [job], returning: [:id])
    repo.query("NOTIFY #{queue}, '#{id}'")
    id
  end

  @doc """
  Dequeue a job.

  Must be called within a transaction.
  The job is removed from the queue if the transaction succeeds, returned otherwise.
  """
  def dequeue(repo, queue) do
    true = repo.in_transaction?()
    query = Query.from(queue,
      order_by: :id,
      limit: 1,
      lock: "FOR UPDATE SKIP LOCKED",
      select: [:id, :data])

    with %{id: id, data: data} <- repo.one(query) do
      repo.delete_all(Query.from queue, where: [id: ^id])
      data
    end
  end

  @doc """
  Wait for an item to be added to the queue
  """
  def wait(queue, timeout) do
    listener = listener(queue)
    {:ok, ref} = Postgrex.Notifications.listen(listener, queue)
    receive do
      {:notification, _pid, _ref, ^queue, _payload} -> :ok
    after
      timeout -> :ok
    end
    Postgrex.Notifications.unlisten(listener, ref)
    clear_notifications(queue)
  end

  defp clear_notifications(queue) do
    receive do
      {:notification, _pid, _ref, ^queue, _payload} -> clear_notifications(queue)
    after
      0 -> :ok
    end
  end

  def listener(queue) do
    "#{queue}_listener" |> String.to_atom()
  end
end
