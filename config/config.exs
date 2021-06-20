# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

# Configure Mix tasks and generators
config :skyscraper,
  ecto_repos: [Skyscraper.Repo]

config :skyscraper_web,
  ecto_repos: [Skyscraper.Repo],
  generators: [context_app: :skyscraper]

# Configures the endpoint
config :skyscraper_web, SkyscraperWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OuNyh0/ZY8ASEcKI7eKCdb9/l9BYaMSFG7xDXPYqcz1MppyzFgtRjiRtrPsKqAJ9",
  render_errors: [view: SkyscraperWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: SkyscraperOtp.PubSub,
  live_view: [signing_salt: "Bxm4dW92"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :skyscraper_web, :pow,
  user: Skyscraper.Users.User,
  repo: Skyscraper.Repo,
  web_module: SkyscraperWeb

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
