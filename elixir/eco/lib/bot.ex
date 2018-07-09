defmodule Bot do
  @behaviour GenServer

  defstruct(
    prefs: [],
    prods: [],
    money: 0,
    price_beliefs: %{},
    inventory: %{},
    created: %{},
    labour: 0,
    turn: 0,
    tracker_pid: nil
  )

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    prodIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    # prepare inventory
    inventory =
      List.foldl(prodIds, %{}, fn elem, acc ->
        Map.put(acc, elem, 0)
      end)

    # prepare productivities
    prods =
      List.foldl(prodIds, %{}, fn elem, acc ->
        Map.put(acc, elem, :rand.uniform())
      end)

    maxLabour = Application.get_env(:eco, :max_labour)

    {:ok,
     %Bot{
       prefs: generate_preferences(prodIds),
       prods: prods,
       inventory: inventory,
       money: 1000,
       labour: maxLabour
     }}
  end

  def handle_info(:turn, state) do
    # if tracker is running, kill it
    if state.tracker_pid, do: GenServer.stop(state.tracker_pid)

    {:ok, trackerPid} = SalesTracker.start
    send(self, :produce)
    send(self, :bid)
    {:noreply, %{state | tracker_pid: trackerPid}}
  end

  def handle_info({:won, productId, amount, ppu}, state) do
    paid = ppu * amount
    newAmount = state.inventory[productId] + amount
    newInventory = %{state.inventory | productId => newAmount}
    {:noreply, %{state | :money => state.money - paid, :inventory => newInventory}}
  end

  def handle_info({:sold, askId, productId, amount, ppu}, state) do
    SalesTracker.reg_sale(state.tracker_pid, askId, amount)
    newAmount = state.created[productId] - amount
    newCreated = %{state.created | productId => newAmount}
    {:noreply, %{state | :money => state.money + amount * ppu, :created => newCreated}}
  end

  def handle_info(:produce, state) do
    {prodId, amount} = ActorUtils.get_best_production_option(state)
    newState = ActorUtils.create(prodId, amount, state)
    submit_asks(TurnMarket, newState)
    {:noreply, newState}
  end

  def handle_info(:bid, state) do
    products = Application.get_env(:eco, :products)
    maxLabour = Application.get_env(:eco, :max_labour)
    labourNeeded = maxLabour - state.labour

    TurnMarket.get_asks_as_list(TurnMarket)
    |> Enum.filter(fn ask ->
      products[ask.product_id].class === :food
    end)
    |> Enum.sort(fn ask1, ask2 ->
      ask1.ppu < ask2.ppu
    end)
    |> place_food_bids(labourNeeded, state.money, TurnMarket)

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_call(_, _from, state) do
    {:reply, :not_implemented, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def place_food_bids([ask | rest], labourNeeded, money, marketPid)
      when labourNeeded > 0 and money > 0 do
    foodValue = Map.get(Application.get_env(:eco, :products), ask.product_id)[:food_value]

    # if price is 0, buy everything
    max = if ask.ppu == 0 do
      ask.amount
    else
      min(ask.amount, trunc(money / ask.ppu))
    end

    if max > 0 do
      spend = max * ask.ppu
      bid = Bid.new(ask.id, max, self())
      TurnMarket.bid(TurnMarket, bid)
      recouped = foodValue * max
      place_food_bids(rest, labourNeeded - recouped, money - spend, marketPid)
    else
      :ok
    end
  end

  def place_food_bids(_, _, _, _) do
    :ok
  end

  def submit_asks(marketPid, state) do
    state.created
    |> Enum.each(fn
      {_, 0} ->
        :ok
      {prodId, amount} ->
        meanPrice = case Map.fetch(state.price_beliefs, prodId) do
          :error ->
            :rand.uniform() * 10
          {:ok, value} ->
            :rstats.rnormal(value, 1)
        end

        ActorUtils.spread_ask(marketPid, prodId, amount, meanPrice, 10, state)
    end)
  end

  # generate prefences adding up to 1
  def generate_preferences(prodIds) do
    nums = for _ <- 1..length(prodIds), do: :rand.uniform()
    sum = Enum.sum(nums)

    prefs = for n <- nums, do: n / sum

    List.zip([prodIds, prefs])
    |> List.foldl(%{}, fn {k, v}, prefMap ->
      Map.put(prefMap, k, v)
    end)
  end

  def get_product_by_id(prodId) do
    Application.get_env(:eco, :products)[prodId]
  end

  def child_spec([id]) do
    %{
      id: id,
      type: :worker,
      start: {Bot, :start_link, []},
      restart: :permanent
    }
  end
end
