defmodule Draftr.Repo do
  use Ecto.Repo,
    otp_app: :draftr,
    adapter: Ecto.Adapters.SQLite3
end
