defmodule Skyscraper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Skyscraper.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Skyscraper.PubSub},
      {Registry, name: Skyscraper.Registry, keys: :unique},
      {DynamicSupervisor, name: Skyscraper.BuildingsSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Skyscraper.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Skyscraper.Supervisor)
  end
end
