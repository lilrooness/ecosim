defmodule Eco do
  use Application

  def start(_type, _args) do
    EcoSup.start_link
    {:ok, _} = Plug.Adapters.Cowboy.http(ControllerPlug, [])
  end

  def stop(_state) do
    :ok
  end
end

defmodule ControllerPlug do
  use Plug.Router

  plug(:cookie)
  plug(:match)
  plug(:dispatch)

  def init(opts) do
    opts
  end

  get "/get_asks" do
    conn
    |> get_asks
    |> put_resp_content_type("application/json")
    |> respond(:get_asks)
  end

  get "/bid" do
    conn
    |> fetch_query_params
    |> bid
    |> respond(:bid)
  end

  get "/ask" do
    conn
    |> fetch_query_params
    |> ask
    |> respond(:ask)
  end

  get "/create" do
    conn
    |> fetch_query_params
    |> create
    |> respond(:create)
  end

  get "/get_state" do
    conn
    |> get_state
    |> respond(:get_state)
  end

  get "/list_products" do
    conn
    |> get_products
    |> respond(:get_products)
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(400, "Not Implemented")
  end

  defp get_products(conn) do
    products =
      Application.get_env(:eco, :products)
      |> Eljiffy.encode()

    conn
    |> Plug.Conn.assign(:products, products)
  end

  defp get_state(conn) do
    encodedState =
      conn.assigns[:controller_id]
      |> ControllerSup.get_pid_by_id()
      |> Controller.get_state()
      |> Eljiffy.encode()

    conn
    |> Plug.Conn.assign(:json_state, encodedState)
  end

  defp bid(conn) do
    {askId, _} =
      Map.get(conn.query_params, "askId")
      |> Integer.parse()

    {amount, _} =
      Map.get(conn.query_params, "amount")
      |> Integer.parse()

    conn.assigns[:controller_id]
    |> ControllerSup.get_pid_by_id()
    |> Controller.bid(askId, amount)

    conn
  end

  defp ask(conn) do
    prodId = Map.get(conn.query_params, "product_id")

    {amount, _} =
      Map.get(conn.query_params, "amount")
      |> Integer.parse()

    {ppu, _} =
      Map.get(conn.query_params, "ppu")
      |> Integer.parse()

    conn.assigns[:controller_id]
    |> ControllerSup.get_pid_by_id()
    |> Controller.ask(prodId, amount, ppu)

    conn
  end

  defp create(conn) do
    prodId = Map.get(conn.query_params, "product_id")

    {amount, _} =
      Map.get(conn.query_params, "amount")
      |> Integer.parse()

    conn.assigns[:controller_id]
    |> ControllerSup.get_pid_by_id()
    |> Controller.create(prodId, amount)

    conn
  end

  defp get_asks(conn) do
    asks =
      TurnMarket.get_asks_as_list(TurnMarket)
      |> Enum.map(fn ask ->
        ask
        |> Map.from_struct()
        |> Map.delete(:from)
      end)
      |> Eljiffy.encode()

    Plug.Conn.assign(conn, :asks, asks)
  end

  defp respond(conn, :get_asks) do
    Plug.Conn.send_resp(conn, 200, conn.assigns[:asks])
  end

  defp respond(conn, :get_state) do
    Plug.Conn.send_resp(conn, 200, conn.assigns[:json_state])
  end

  defp respond(conn, :get_products) do
    Plug.Conn.send_resp(conn, 200, conn.assigns[:products])
  end

  defp respond(conn, _) do
    Plug.Conn.send_resp(conn, 200, "OK")
  end

  # plugs
  def cookie(conn, _opts) do
    conn
    |> Plug.Conn.fetch_cookies()
    |> ensure_cookie
  end

  defp ensure_cookie(conn) do
    if has_controller(conn) do
      controllerId = Map.get(conn.cookies, "session")

      conn
      |> Plug.Conn.assign(:controller_id, controllerId)
    else
      # start new controller process
      id = ControllerSup.new_controller()

      conn
      |> Plug.Conn.put_resp_cookie("session", id)
      |> Plug.Conn.assign(:controller_id, id)
    end
  end

  defp has_controller(conn) do
    id = Map.get(conn.cookies, "session", :undef)

    case ControllerSup.get_pid_by_id(id) do
      :undefined ->
        false

      _pid ->
        true
    end
  end
end
