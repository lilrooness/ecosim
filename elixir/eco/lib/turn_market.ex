defmodule TurnMarket do

  defstruct(
    turn: 0,
    asks: [],
    bids: [],
    pastTurns: []
  )
    
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, %TurnMarket{}}
  end

  def handle_call({:ask, productId, amount, ppu}, from, state) do
    askId = UUID.uuid1()
    newState = %{state | :asks =>
      state.asks ++ [{askId, {productId, from, amount, ppu}}]}
    {:reply, askId, newState}
  end

  def handle_call({:bid, askId, amount}, from, state) do
    newState = %{state | :bids =>
      state.bids ++ [{askId, {amount, from}}]}
    {:reply, newState}
  end

  def handle_call(:get_turns, _from, state) do
    {:reply, state.pastTurns, state}
  end
  
  def handle_cast(:settle, state) do
    bids = Enum.shuffle(state.bids)
    foldFun = fn(elem, acc) ->
      {:ok, newAcc} = resolve_bid(elem, acc)
      newAcc
    end

    newAsks = List.foldl(bids, state.asks, foldFun)

    saveTurn = %TurnMarket{
      :turn => state.turn,
      :asks => newAsks,
      :bids => state.bids
    }
    
    newTurns = [saveTurn | state.turns]
    {:noreply, %{state |
		 :turn => state.turn + 1,
		 :asks => [],
		 :bids => [],
		 :pastTurns => newTurns}}
  end

  def resolve_bid({askId, {amount, buyer}}, asks) do
    {productId, seller, avail, ppu} = :proplists.get_value(askId, asks)
    saleAmount = if amount <= avail do
      amount
    else
      avail
    end

    send(buyer, {:won, productId, saleAmount, ppu})
    send(seller, {:sold, productId, saleAmount, ppu})

    newAsks = List.keydelete(asks, askId, 1) ++ [{askId, {productId, seller, avail - saleAmount, ppu}}]
    {:ok, newAsks}
  end

  def get_past_turns() do
    GenServer.call(TurnMarket, :get_turns)
  end
  
  
end
