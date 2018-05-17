defmodule Controller do
  use GenServer

  def start_link(id) do
    GenServer.start(__MODULE__, [id], [])
  end

  def init([id]) do
    products = for {id, _} <- Application.get_env(:eco, :products), do: id
    sellables = List.foldl(products, %{}, fn(elem, acc) ->
      Map.put(acc, elem, 0)
    end)
    consumables = List.foldl(products, %{}, fn(elem, acc) ->
      Map.put(acc, elem, 0)
    end)
    {:ok, %{
      :funds => 1000,
      :max_labour => 1000,
      :labour => 1000,
      :id => id,
      :preferences => Person.generate_preferences(products),
      :productivities => Person.generate_productivities(products),
      :sellables => sellables,
      :consumables => consumables,
      :product_path => false
    }}
  end

  def handle_cast({:bid, askId, amount}, state) do
    ask = SMarket.get_ask(SMarket, askId)
    spend = ask.unit_price * amount
    SMarket.bid(SMarket, askId, amount, spend, self())
    {:noreply, %{state | :funds => state.funds - spend}}
  end

  def handle_info({:won, info}, state) do
    productId = info[:product_id]
    amount = info[:amount]
    newConsumables = %{state.consumables | productId => state.consumables[productId] + amount}
    {:noreply, %{state | :consumables => newConsumables}}
  end

  def handle_info({:lost, info}, state) do
    %{state | :funds => state.funds + info.total_spend}
  end

  def handle_info({:sold, info}, state) do
    productId = info[:product_id]
    amount = info[:amount]
    netGain = info[:net_gain]
    newSellables = %{state.sellables | productId => state.sellables[productId] - amount}
    {:noreply, %{state | :sellables => newSellables,
               :funds => state.funds + netGain}}
  end

  def bid(pid, askId, amount) do
    GenServer.cast(pid, {:bid, askId, amount})
  end

end
