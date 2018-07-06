defmodule TurnMarket do
  @behaviour GenServer

  defstruct(
    turn: 0,
    asks: %AskList{},
    bids: [],
    pastTurns: []
  )

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API
  def get_past_turns(marketPid) do
    GenServer.call(marketPid, :get_turns)
  end

  def ask(marketPid, prodId, amount, ppu) do
    GenServer.call(marketPid, {:ask, prodId, amount, ppu})
  end

  def bid(marketPid, %Bid{} = bid) do
    GenServer.call(marketPid, {:bid, bid})
  end

  def get_asks(marketPid) do
    GenServer.call(marketPid, :get_asks)
  end

  def get_bids(marketPid) do
    GenServer.call(marketPid, :get_bids)
  end

  def get_asks_as_list(marketPid) do
    GenServer.call(marketPid, :list_asks)
  end

  def settle(marketPid) do
    GenServer.cast(marketPid, :settle)
  end

  # CALLBACKS
  def init([]) do
    {:ok, %TurnMarket{}}
  end

  def handle_call({:ask, prodId, amount, ppu}, {fromPid, _}, state) do
    asks = AskList.add(state.asks, prodId, fromPid, amount, ppu)
    newState = %{state | :asks => asks}
    id = AskList.get_last_id(asks)
    {:reply, id, newState}
  end

  def handle_call({:bid, %Bid{} = bid}, {fromPid, _}, state) do
    # if ask exists, then log bid
    case AskList.fetch(state.asks, bid.ask_id) do
      {:ok, _ask} ->
        bidWithFrom = Map.put(bid, :from, fromPid)
        newState = %{state | :bids => [bidWithFrom | state.bids]}
        {:reply, :ok, newState}

      :error ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:list_asks, _from, state) do
    askList = AskList.list_asks(state.asks)
    {:reply, askList, state}
  end

  def handle_call(:get_asks, _from, state) do
    {:reply, state.asks, state}
  end

  def handle_call(:get_bids, _from, state) do
    {:reply, state.bids, state}
  end

  def handle_call(:get_turns, _from, state) do
    {:reply, state.pastTurns, state}
  end

  def handle_cast(:settle, state) do
    newState =
      Enum.shuffle(state.bids)
      |> Enum.reduce(state, &resolve_bid/2)

    {:noreply, %{newState | :bids => []}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def code_change(_oldVsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  # UTILS
  defp resolve_bid(%Bid{} = bid, state) do
    {:ok, ask} = AskList.fetch(state.asks, bid.ask_id)

    buyAmount =
      if bid.amount >= ask.amount do
        ask.amount
      else
        bid.amount
      end

    send(ask.from, {:sold, ask.product_id, buyAmount, ask.ppu})
    send(bid.from, {:won, ask.product_id, buyAmount, ask.ppu})
    remaining = ask.amount - buyAmount
    newAsks = put_in(state.asks, [bid.ask_id, :amount], remaining)
    %{state | :asks => newAsks}
  end
end
