# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Customize the firmware. Uncomment all or parts of the following
# to add files to the root filesystem or modify the firmware
# archive.

# config :nerves, :firmware,
#   rootfs_additions: "config/rootfs_additions",
#   fwup_conf: "config/fwup.conf"

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

#url: [host: "192.168.0.4", port: 80],

# import_config "#{Mix.Project.config[:target]}.exs"
config :logger, level: :debug

config :nerves_interim_wifi,
  regulatory_domain: "PE"

config :ui, Ui.Endpoint,
  http: [port: 80],
  url: [host: "192.168.0.7", port: 80],
  secret_key_base: "WiCLsSiI5RcVdtO7zKkzwMtVIjqkIgiOoP3vkiqLFq3VGVtmlz23OPGl28syn6BQ",
  root: Path.dirname(__DIR__),
  server: true,
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Ui.PubSub,
           adapter: Phoenix.PubSub.PG2],
  debug_errors: true,
  code_reload: false

import_config "secret.exs"
