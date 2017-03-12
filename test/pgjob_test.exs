defmodule PgjobTest do
  use ExUnit.Case
  require Ecto.Query, as: Query
  alias Pgjob.Repo

  doctest Pgjob

  setup do
    Repo.delete_all("jobs")
    :ok
  end

  test "Adding a job" do
    id = Pgjob.enqueue(Repo, "jobs", PgjobTest, :run, %{a: 1, b: "hello"})
    assert id > 0
    query = Query.from(job in "jobs", where: job.id == ^id, select: [:id, :data])
    assert %{id: ^id, data: data} = Repo.one(query)
    assert data == %{"module" => "Elixir.PgjobTest", "function" => "run", "args" => %{"a" => 1, "b" => "hello"}}
  end

  test "Dequeued job is removed from database" do
    id = Pgjob.enqueue(Repo, "jobs", PgjobTest, :run, %{a: 1, b: "hello"})
    Pgjob.Repo.transaction fn -> Pgjob.dequeue(Repo, "jobs") end
    assert [] = Repo.all(Query.from("jobs", select: [:id]))
  end

  test "Dequeue when no jobs produces nil" do
    assert {:ok, nil} = Pgjob.Repo.transaction fn -> Pgjob.dequeue(Repo, "jobs") end
  end

  test "dequeue requires a transaction" do
    Pgjob.enqueue(Repo, "jobs", PgjobTest, :run, %{a: 1, b: 2})
    assert_raise MatchError, fn -> Pgjob.dequeue(Repo, "jobs") end
  end

  test "aborting transaction leaves job in queue" do
    Pgjob.enqueue(Repo, "jobs", Pgjobtest, :run, %{a: 1, b: 2})
    assert {:error, :fail} = Pgjob.Repo.transaction fn ->
      %{"module" => _, "function" => _, "args" => _} = Pgjob.dequeue(Repo, "jobs")
      Pgjob.Repo.rollback(:fail)
    end
    assert {:ok, %{"module" => _, "function" => _, "args" => _}} = Pgjob.Repo.transaction fn -> Pgjob.dequeue(Repo, "jobs") end
    assert {:ok, nil} = Pgjob.Repo.transaction fn -> Pgjob.dequeue(Repo, "jobs") end
  end

  test "dequeuing jobs concurrently" do
    Enum.each 1..100, fn i ->
      Pgjob.enqueue(Repo, "jobs", Pgjobtest, :run, %{a: i})
    end

    parent = self()
    pids = Enum.map 1..5, fn  _ ->
      spawn fn ->
        Enum.each 1..20, fn _ ->
          Repo.transaction fn ->
            %{"module" => _, "function" => _, "args" => %{"a" => i}} = Pgjob.dequeue(Repo, "jobs")
            send(parent, i)
          end
        end
      end
    end

    Enum.each 1..100, fn i ->
      receive do
        ^i -> :ok
      after
        100 -> flunk("Didn't receive acknowledgement of job #{i}")
      end
    end
  end
end
