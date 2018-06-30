defmodule Eco do
  use Application

  def start(_type, _args) do
    TurnMarket.start_link
    {:ok, _} = Plug.Adapters.Cowboy.http ControllerPlug, []
  end

  def stop(_state) do
    :ok
  end
end

defmodule ControllerPlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello World")
  end

end
