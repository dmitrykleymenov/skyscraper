defmodule Skyscraper.Repo do
  use Ecto.Repo,
    otp_app: :skyscraper,
    adapter: Ecto.Adapters.Postgres
end
