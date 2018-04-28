defmodule SMarket do

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, %{
      :asks => %{}
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

  def handle_call(:get_asks, _from, state) do
    {:reply, {:ok, state.asks}, state}
  end

  def handle_cast({:bid, askId, amount, spend, buyerPid}, state) do
    ask = state.asks[askId]
    asks = handle_bid(askId, ask, amount, buyerPid, spend, state)
    {:noreply, %{state | :asks => asks}}
  end

  def handle_bid(_askId, nil, _amount, buyerPid, spend, state) do
    # TODO: Figure out how to return money to unsuccessful buyer
    send(buyerPid, {:lost, [total_price: spend]})
    state
  end

  def handle_bid(askId, ask, amount, buyerPid, _spend, state) do
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
    {:ok, asks} = GenServer.call(marketPid, :get_asks);
    {:ok, (for ask <- asks, products[asks.product_id].class == type, do: ask)}
  end

  def bid(marketPid, askId, amount, spend, buyerPid) do
    GenServer.cast(marketPid, {:bid, askId, amount, spend, buyerPid})
  end
end
