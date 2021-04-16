defmodule SkyscraperWeb.PageController do
  use SkyscraperWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
