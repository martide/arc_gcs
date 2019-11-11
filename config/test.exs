use Mix.Config

config :arc, :bucket, System.get_env("ARC_TEST_BUCKET")

config :goth, json: System.get_env("GOOGLE_CREDENTIAL")
