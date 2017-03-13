defmodule DemoTest do
  use ExUnit.Case
  require Ecto.Query, as: Query
  alias Demo.{Jobs, Repo}

  setup do
    Repo.delete_all("jobs")
    :ok
  end

  test "Adding a job" do
    id = Jobs.enqueue(Demo, :run, %{a: 1, b: "hello"})
    assert id > 0
    query = Query.from(job in "jobs", where: job.id == ^id, select: [:id, :data])
    assert %{id: ^id, data: data} = Repo.one(query)
    assert data == %{"module" => "Elixir.Demo", "function" => "run", "args" => %{"a" => 1, "b" => "hello"}}
  end

  test "Dequeued job is removed from database" do
    _id = Jobs.enqueue(Demo, :run, %{a: 1, b: "hello"})
    Repo.transaction fn -> Jobs.dequeue() end
    assert [] = Repo.all(Query.from("jobs", select: [:id]))
  end

  test "Dequeue when no jobs produces nil" do
    assert {:ok, nil} = Repo.transaction fn -> Jobs.dequeue() end
  end

  test "dequeue requires a transaction" do
    Jobs.enqueue(Demo, :run, %{a: 1, b: 2})
    assert_raise MatchError, fn -> Jobs.dequeue() end
  end

  test "aborting transaction leaves job in queue" do
    Jobs.enqueue(Demo, :run, %{a: 1, b: 2})
    assert {:error, :fail} = Repo.transaction fn ->
      %{"module" => _, "function" => _, "args" => _} = Jobs.dequeue()
      Repo.rollback(:fail)
    end
    assert {:ok, %{"module" => _, "function" => _, "args" => _}} = Repo.transaction fn -> Jobs.dequeue() end
    assert {:ok, nil} = Repo.transaction fn -> Jobs.dequeue() end
  end

  test "dequeuing jobs concurrently" do
    Enum.each 1..100, fn i ->
      Jobs.enqueue(Demo, :run, %{a: i})
    end

    parent = self()
    _pids = Enum.map 1..5, fn  _ ->
      spawn fn ->
        Enum.each 1..20, fn _ ->
          Repo.transaction fn ->
            %{"module" => _, "function" => _, "args" => %{"a" => i}} = Jobs.dequeue()
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
