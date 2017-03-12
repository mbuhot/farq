defmodule Pgjob.Repo.Migrations.Jobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :data, :map, null: false
    end
  end
end
