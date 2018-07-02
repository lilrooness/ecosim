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
  use Plug.Router

  plug :match
  plug :dispatch

  def init(opts) do
    opts
  end

  get "/get_asks" do
    conn
    |> get_asks
    |> put_resp_content_type("application/json")
    |> respond(:get_asks)
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(400, "Not Implemented")
  end

  defp get_asks(conn) do
    asks = TurnMarket.get_asks_as_list(TurnMarket)
    |> Enum.map(fn(ask) ->
      ask 
      |> Map.from_struct
      |> Map.delete(:from) 
    end)
    |> Eljiffy.encode
    Plug.Conn.assign(conn, :asks, asks)
  end

  defp respond(conn, :get_asks) do
    Plug.Conn.send_resp(conn, 200, conn.assigns[:asks])
  end

end
