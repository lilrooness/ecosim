defmodule SMarket do

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    prodIds = (for {prodId, _} <- Application.get_env(:eco, :products), do: prodId)
    demands = List.foldl(prodIds, %{}, fn(prodId, acc) -> Map.put(acc, prodId, 0) end)
    {:ok, %{
      :asks => %{},
      :demands => demands
    }}
  end

  def handle_call({:ask, productId, unitPrice, amount, sellerPid}, _from, state) do
    askId = UUID.uuid1()
    ask = %{
      :product_id => productId,
      :unit_price => unitPrice,
      :amount => amount,
      :seller_pid => sellerPid
    }
    {:reply, {:ok, askId}, %{state |
      :asks => Map.put(state.asks, askId, ask)
      }
    }
  end

  def handle_call({:get_ask, askId}, _from, state) do
    {:reply, {:ok, state.asks[askId], state}}
  end

  def handle_call(:get_asks, _from, state) do
    {:reply, {:ok, state.asks}, state}
  end

  def handle_cast({:bid, askId, amount, spend, buyerPid}, state) do
    ask = state.asks[askId]
    asks = handle_bid(askId, ask, amount, buyerPid, spend, state)
    {:noreply, %{state | :asks => asks}}
  end

  def handle_cast({:demand, productId, quantity}, state) do
    newDemand = %{state.demand | productId  => state.demand[productId] + quantity}
    {:noreply, %{state | :demand => newDemand}}
  end

  def handle_bid(_askId, nil, _amount, buyerPid, spend, state) do
    # TODO: Figure out how to return money to unsuccessful buyer
    send(buyerPid, {:lost, [total_price: spend]})
    state
  end

  def handle_bid(askId, ask, amount, buyerPid, _spend, state) do
    demand(self(), ask.product_id, amount)
    sold = if ask.amount >= amount do
      send(buyerPid, {:won, [product_id: ask.product_id, amount: amount, total_price: ask.unit_price * amount]})
      send(ask.seller_pid, {:sold, [product_id: ask.product_id, amount: amount, net_gain: amount*ask.unit_price]})
      amount
    else
      send(buyerPid, {:lost, [total_price: ask.unit_price * amount]})
      0
    end

    if ask.amount - sold <= 0 do
      %{state.asks | askId => nil}
    else
      %{state.asks | askId => %{ask | :amount => ask.amount - sold}}
    end
  end

  def get_asks_of_type(marketPid, type) do
    products = Application.get_env(:eco, :products)
    {:ok, askMaps} = GenServer.call(marketPid, :get_asks)
    asks = for {askId, ask} <- askMaps, do: {askId, ask}
    {:ok, (for {askId, ask} <- asks, products[ask.product_id].class == type, do: {askId, ask})}
  end

  def bid(marketPid, askId, amount, spend, buyerPid) do
    GenServer.cast(marketPid, {:bid, askId, amount, spend, buyerPid})
  end

  def ask(marketPid, productId, unitPrice, amount, sellerPid) do
    GenServer.call(marketPid, {:ask, productId, unitPrice, amount, sellerPid})
  end

  def demand(marketPid, productId, quantity) do
    GenServer.cast(marketPid, {:demand, productId, quantity})
    :ok
  end

  def get_ask(marketPid, askId) do
    GenServer.call(marketPid, {:get_ask, askId})
  end
end
