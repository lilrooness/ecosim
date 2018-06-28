defmodule Controller do
  use GenServer

  defstruct(
    id: 0,
    prods: [],
    money: 0,
    inventory: %{},
    created: %{},
    labour: 0
  )

  def start_link(id) do
    GenServer.start(__MODULE__, [id], [])
  end

  # API

  def bid(controller, askId, amount) do
    GenServer.call(controller, {:bid, askId, amount})
  end

  def ask(controller, prodId, amount, ppu) do
    GenServer.call(controller, {:ask, prodId, amount, ppu})
  end

  def get_state(controller) do
    GenServer.call(controller, :get_state)
  end

  # CALLBACKS

  def init([id]) do
    # products = for {id, _} <- Application.get_env(:eco, :products), do: id
    prodIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    # prepare inventory
    inventory = List.foldl(prodIds, %{}, fn(elem, acc) ->
      Map.put(acc, elem, 0)
    end)

    prods = List.foldl(prodIds, %{}, fn(elem, acc) ->
      Map.put(acc, elem, :rand.uniform)
    end)

    maxLabour = Application.get_env(:eco, :max_labour)

    {:ok, %Controller{
      :id => id,
      :prods => prods,
      :inventory => inventory,
      :labour => maxLabour,
      :money => 1000
    }}
  end

  def handle_call({:bid, askId, amount}, _from, state) do
    response = if can_bid(askId, state) >= amount do
      bid = Bid.new(askId, amount, self())
      TurnMarket.bid(TurnMarket, bid)
      :ok
    else
      {:error, {:insufficient_funds, state.money}}
    end

    {:reply, response, state}
  end

  def handle_call({:ask, prodId, amount, ppu}, _from, state) do
    forSale = can_sell(prodId, state)
    response = if forSale >= amount do
      askId = TurnMarket.ask(TurnMarket, prodId, amount, ppu)
      {:ok, askId}
    else
      {:error, {:insufficient_product, forSale}}
    end

    {:reply, response, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp can_sell(productId, state) do
    Map.get(state.created, productId, 0)
  end

  defp can_bid(askId, state) do
    lookup = TurnMarket.get_asks(TurnMarket)
      |> AskList.get(askId, nil)

    case lookup do
      nil ->
        {:error, :invalid_ask_id}
      ask ->
        trunc(state.money / ask.ppu)
    end
  end
end
