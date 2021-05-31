defmodule SkyscraperOtp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, name: SkyscraperOtp.Registry, keys: :unique},
      {DynamicSupervisor, name: SkyscraperOtp.BuildingsSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: SkyscraperOtp.TaskSupervisor},
      {Phoenix.PubSub, name: SkyscraperOtp.PubSub},
      SkyscraperOtp.Cleaner.Server,
      SkyscraperOtp.Cache
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SkyscraperOtp.Supervisor)
  end
end
