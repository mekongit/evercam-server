use Mix.Config

# For production, we configure the host to read the PORT
# from the system environment. Therefore, you will need
# to set PORT=80 before running your server.
#
# You should also configure the url host to something
# meaningful, we use this information when generating URLs.
config :evercam_media, EvercamMediaWeb.Endpoint,
  check_origin: false,
  http: [port: 4000],
  url: [host: "media.evercam.io"],
  static_url: [host: "media.evercam.io", port: 443, scheme: "https"],
  email: "Evercam <support@evercam.io>"

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section:
#
#  config:evercam_media, EvercamMedia.Endpoint,
#    ...
#    https: [port: 443,
#            keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#            certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables point to a file on
# disk for the key and cert.

# Do not print debug messages in production
config :logger, level: :info

# Filter out these fields from the logs
config :phoenix, :filter_parameters, ["password", "api_key"]

config :evercam_media, :create_intercom_user, true

# Start spawn process or not
config :evercam_media, :run_spawn, true

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :evercam_media, EvercamMedia.Endpoint, server: true
#

config :evercam_media,
  hls_url: "https://media.evercam.io/hls"

config :evercam_media,
  start_camera_workers: System.get_env["START_CAMERA_WORKERS"]

config :evercam_media,
  start_evercam_bot: true

config :evercam_media,
  start_timelapse_workers: false

config :evercam_media,
  storage_dir: "/storage"

config :evercam_media,
  files_dir: "/data"

config :evercam_media,
  EvercamMedia.Scheduler,
  overlap: false,
  jobs: [
    {"@daily", {EvercamMedia.Util, :kill_all_ffmpegs, []}},
    {"@hourly", {EvercamMedia.ShareRequestReminder, :check_share_requests, []}},
    {"@hourly", {EvercamMedia.OfflinePeriodicReminder, :offline_cameras_reminder, []}},
    {"* * * * *", {EvercamMedia.Util, :check_camera_streams, [0]}},
    {"* * * * *", {EvercamMedia.Util, :check_camera_streams, [30000]}}
  ]

config :evercam_media, EvercamMedia.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.get_env("MAILGUN_KEY"),
  domain: System.get_env("MAILGUN_DOMAIN")

config :evercam_models, Evercam.Repo,
  types: Evercam.PostgresTypes,
  url: System.get_env("DATABASE_URL"),
  socket_options: [keepalive: true],
  timeout: 60_000,
  pool_size: 80,
  lazy: false,
  ssl: true

config :evercam_models, Evercam.SnapshotRepo,
  url: System.get_env("SNAPSHOT_DATABASE_URL"),
  socket_options: [keepalive: true],
  timeout: 60_000,
  pool_size: 100,
  lazy: false,
  ssl: true

config :evercam_media, EvercamMedia.Scheduler,
  debug_logging: false
