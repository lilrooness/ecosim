defmodule Eco do
  use Application

  def start(_type, _args) do
    dispatch = :cowboy_router.compile([
     {:_, [{"/ws", EcoWebsocketHandler, []}]}
    ])

    SMarket.start_link

    :cowboy.start_clear(:ws_listener, [port: 8080], %{:env => %{:dispatch => dispatch}})
  end

  def stop(_state) do
    :ok
  end

end

defmodule EcoWebsocketHandler do
  def init(req, _state) do
    {:cowboy_websocket, req, _newState = %{}, %{:idle_timeout => 60000 * 20}}
  end

  def websocket_init(state) do
    {:ok, state}
  end

  def websocket_handle({:text, _data}, state) do
    {:ok, state}
  end

  # def websocket_info({:msg, msg}, state) do
  #   data = Eljiffy.encode(msg)
  #   {:reply, {:text, data}, state}
  # end

  def terminate(_reason, _req, _state) do
    :ok
  end
end

