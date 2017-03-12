defmodule Pgjob do
  @moduledoc """
  Documentation for Pgjob.
  """

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
    query = Query.from(queue, order_by: :id, limit: 1, lock: "FOR UPDATE SKIP LOCKED", select: [:id, :data])
    with %{id: id, data: data} <- repo.one(query) do
      repo.delete_all(Query.from queue, where: [id: ^id])
      data
    end
  end
end
