defmodule SMarket do

  def start_link() do
    GenServer.start_link(__MODULE__, [], []) 
  end

  def init() do
    {:ok, %{
      :asks => %{},
      :bids => %{}
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
      :asks => Map.put(state.asks, askId, ask),
      :bids => Map.put(state.bids, askId, [])
      }
    }
  end

  def handle_cast({:bid, askId, amount, buyerPid}, state) do
     bid = %{
       :amount => amount,
       :buyer_pid => buyerPid
     }
     bids = %{state.bids | askId => state.bids[askId] ++ [bid]}
     {:noreply, %{state | :bids => bids}}
  end

  def handle_info(:clear, state) do
    clear_asks(state.asks, state.bids)
  end

  def clear_asks([], _) do
    :ok
  end

  def clear_asks([ask | rest], bids) do
    shuffledBids = Enum.shuffle bids[ask[:ask_id]]
    sold = clear_bids(shuffledBids, ask, 0)
    send ask.seller_pid, {:sold, [product_id: ask.productId,
                                  amount: sold,
				  net_gain: sold*ask.unit_price]}
    clear_asks(rest, bids)
  end

  def clear_bids([], _, sold) do
    sold
  end

  def clear_bids([bid | rest], %{:amount => amount} = ask, sold) when amount > 0 do
    amountSold = if ask.amount >= bid.amount do
      bid.amount
    else
      bid.amount - ask.amount
    end

    send bid.buyer_pid, {:won, [product_id: bid.product_id,
                                amount: amountSold,
				total_price: ask.unit_price * amountSold]}
    newAmount = ask.amount - amountSold
    clear_bids(rest, %{ask | :amount => newAmount}, sold + amountSold)
  end

  def clear_bids(_, _, sold) do
    sold
  end

end
