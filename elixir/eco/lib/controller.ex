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

  def create(controller, productId, amount) do
    GenServer.cast(controller, {:create, productId, amount})
  end

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
    prodIds = for {prodId, _} <- Application.get_env(:eco, :products), do: prodId
    # prepare inventory
    inventory =
      List.foldl(prodIds, %{}, fn elem, acc ->
        Map.put(acc, elem, 0)
      end)

    prods =
      List.foldl(prodIds, %{}, fn elem, acc ->
        Map.put(acc, elem, :rand.uniform())
      end)

    maxLabour = Application.get_env(:eco, :max_labour)

    {:ok,
     %Controller{
       :id => id,
       :prods => prods,
       :inventory => inventory,
       :labour => maxLabour,
       :money => 1000
     }}
  end

  def handle_info({:won, productId, amount, ppu}, state) do
    paid = ppu * amount
    newAmount = state.inventory[productId] + amount
    newInventory = %{state.inventory | productId => newAmount}
    {:noreply, %{state | :money => state.money - paid, :inventory => newInventory}}
  end

  def handle_info({:sold, productId, amount, ppu}, state) do
    newAmount = state.created[productId] - amount
    newCreated = %{state.created | productId => newAmount}
    {:noreply, %{state | :money => state.money + amount * ppu, :created => newCreated}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def handle_call({:bid, askId, amount}, _from, state) do
    response =
      if can_bid(askId, state) >= amount do
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

    response =
      if forSale >= amount do
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

  def handle_cast({:create, productId, amount}, state) do
    newState =
      if can_create(productId, state) >= amount do
        ActorUtils.create(productId, amount, state)
      else
        state
      end

    {:noreply, newState}
  end

  def code_change(_oldVsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp can_sell(productId, state) do
    Map.get(state.created, productId, 0)
  end

  defp can_create(productId, state) do
    Application.get_env(:eco, :products)
    |> Map.get(productId, nil)
    |> ActorUtils.can_create(state)
  end

  defp can_bid(askId, state) do
    lookup =
      TurnMarket.get_asks(TurnMarket)
      |> AskList.get(askId, nil)

    case lookup do
      nil ->
        0

      ask ->
        trunc(state.money / ask.ppu)
    end
  end
end
