defmodule TurnMarket do

  defstruct(
    turn: 0,
    asks: [],
    bids: []
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

  def handle_cast(:settle, state) do
    bids = Enum.shuffle(state.bids)
    foldFun = fn(elem, acc) ->
      {:ok, newAcc} = resolve_bid(elem, acc)
      newAcc
    end
    
    newAsks = List.foldl(bids, state.asks, foldFun)
    {:noreply, %{state | :asks => newAsks}}
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

    newAsks = List.keydelete(asks, askId, 1) ++ [{askId, {productId, seller, avail, ppu}}]
    {:ok, newAsks}
  end
  
end
