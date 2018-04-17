defmodule Market do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, %{
        :lots => %{},
	:product_prices => %{}
      }}
  end

  def handle_call(:get_lots, _from, state) do
    {:reply, state.lots, state}
  end

  def handle_call({:sell, productId, amount, basePrice, sellerPid}, _from, state) do
    lotNumber = UUID.uuid1()
    lot = %{
      :product_id => productId,
      :amount => amount,
      :seller_pid => sellerPid,
      :bids => [%{:price => basePrice, :amount => 1, :bidder_pid => sellerPid}]
    }
    {:reply, {:ok, lotNumber}, %{state | :lots => Map.put(state.lots, lotNumber, lot)}}
  end

  def handle_cast({:bid, lotNumber, price, amount, bidderPid}, state) do
    bid = %{
      :price => price,
      :amount => amount,
      :bidder_pid => bidderPid
    }
    
    updatedLots = case state.lots[lotNumber] do
      nil ->
        state.lots
      lot ->
        if bid.amount <= lot.amount do
          %{state.lots | lotNumber => Map.put(lot, :bids, lot.bids ++ [bid])}
	else
          state.lots
	end
    end
    {:noreply, %{state | :lots => updatedLots}}
  end

  def handle_cast(:clear_all_bids, state) do
    for {lotNumber, _lot} <- state.lots, do: clear_bids(lotNumber, state)
    {:noreply, %{state | :lots => %{}}}
  end

  defp clear_bids(lotNumber, state) do
    lot = state.lots[lotNumber]
    # Sort bids high to low
    bids = Enum.sort(lot[:bids], 
                      &(&1[:price] >= &2[:price]))
    
    clear_bids(bids, lot.amount, lot.seller_pid, lot.product_id, lotNumber, 0, [])
  end

  defp clear_bids([], remainingStock, sellerPid, productId, lotNumber, lastSalePrice, unfulfilledOrders) do
    sell_fixed_price(unfulfilledOrders, sellerPid, remainingStock, lastSalePrice, lotNumber, productId)
  end

  defp clear_bids([bid | rest], stock, sellerPid, productId, lotNumber, lastSalePrice, unfulfilledOrders) do
    {soldAmount, salePrice, unfulfilled} = if bid.amount <= stock do
      send(bid.bidder_pid, {:won_bid, 
        [product_id: productId,
	 amount: bid.amount,
	 payable: bid.price * bid.amount,
	 lot_number: lotNumber]})
      send(sellerPid, {:sold,
        [lot_number: lotNumber,
	 amount: bid.amount,
	 total_price: bid.price * bid.amount]})
      {bid.amount, bid.price, unfulfilledOrders}
    else
      {0, lastSalePrice, unfulfilledOrders ++ [bid]}
    end
    clear_bids(rest, stock - soldAmount, sellerPid, productId, lotNumber, salePrice, unfulfilled)
  end

  defp sell_fixed_price([], _sellerPid, stock, _price, _lotNumber, _productId) do
    stock
  end

  defp sell_fixed_price(_bids, _sellerPid, 0, _price, _lotNumber, _productId) do
    0
  end

  defp sell_fixed_price([bid | rest], sellerPid, stock, price, lotNumber, productId) do
    newStock = cond do
      bid.amount <= stock ->
        send(sellerPid, sale_msg(lotNumber, bid.amount, price * bid.amount))
        send(bid.bidder_pid, bid_won_msg(lotNumber, bid.amount, price * bid.amount, productId))
	stock - bid.amount
      bid.amount > stock ->
        send(sellerPid, sale_msg(lotNumber, stock, price * stock))
	send(bid.bidder_pid, bid_won_msg(lotNumber, stock, price * stock, productId))
	0
    end
    sell_fixed_price(rest, sellerPid, newStock, price, lotNumber, productId)
  end

  defp sale_msg(lotNumber, amount, totalPrice) do
    {:sold, [
      lot_number: lotNumber,
      amount: amount,
      total_price: totalPrice
    ]}
  end

  defp bid_won_msg(lotNumber, amount, payable, productId) do
    {:won_bid, [
      lot_number: lotNumber,
      amount: amount,
      payable: payable,
      product_id: productId
    ]}
  end

  def get_lots(pid) do
    GenServer.call(pid, :get_lots)
  end

end

