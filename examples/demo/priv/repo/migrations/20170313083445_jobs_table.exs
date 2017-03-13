defmodule Demo.Repo.Migrations.JobsTable do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :data, :map, null: false
      add :in_progress, :boolean, default: false, null: false
    end
  end
end
