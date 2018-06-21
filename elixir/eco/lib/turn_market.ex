defmodule TurnMarket do
  @behaviour GenServer
  
  defstruct(
    turn: 0,
    asks: %AskList{},
    bids: [],
    pastTurns: []
  )
    
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, %TurnMarket{}}
  end

  def handle_call({:ask, prodId, amount, ppu}, from, state) do
    asks = AskList.add(state.asks, prodId, from, amount, ppu)
    newState = %{state | :asks => asks}
    id = AskList.get_last_id(asks)
    {:reply, id, newState}
  end

  def handle_call({:bid, %Bid{} = bid}, from, state) do
    newState = %{state | :bids =>[bid | state.bids]}
    {:reply, newState}
  end

  def handle_call(:get_turns, _from, state) do
    {:reply, state.pastTurns, state}
  end
  
  def handle_cast(:settle, state) do
    newState = Enum.shuffle state.bids
    |>Enum.reduce(state, &resolve_bid/2)
    {:noreply, newState}
  end

  def resolve_bid(%Bid{} = bid, state) do
    {:ok, ask} = AskList.fetch(state.asks, bid.ask_id)
    buyAmount = if bid.amount >= ask.amount do
      ask.amount
    else
      bid.amount
    end

    send(ask.from, {:sold, ask.product_id, buyAmount, ask.ppu})
    send(bid.from, {:won, ask.product_id, buyAmount, ask.ppu})

    newAsks = put_in(state.asks, [bid.ask_id, :amount], buyAmount)
    %{state | :asks => newAsks}
  end
  
  def get_past_turns() do
    GenServer.call(TurnMarket, :get_turns)
  end
end
