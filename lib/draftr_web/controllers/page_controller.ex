defmodule DraftrWeb.PageController do
  use DraftrWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
