defmodule Bot do

  defstruct(
    prefs: [],
    prods: [],
    money: 0,
    inventory: %{},
    created: %{},
    labour: 0,
    turn: 0
  )
  
  
  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    prodIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    # prepare inventory
    inventory = List.foldl(prodIds, %{},
      fn(elem, acc) ->
	Map.put(acc, elem, 0)
      end)
    # prepare productivities
    prods = List.foldl(prodIds, %{},
      fn(elem, acc) ->
	Map.put(acc, elem, :rand.uniform)
      end)
    maxLabour = Application.get_env(:eco, :max_labour)
    {:ok, %Bot{
	prefs: generate_preferences(prodIds),
	prods: prods,
	inventory: inventory,
	money: 1000,
	labour: maxLabour
     }}
  end

  def handle_info({:won, productId, amount, ppu}, state) do
    paid = ppu * amount
    newAmount = state.inventory[productId] + amount
    newInventory = %{state.inventory | productId => newAmount}
    {:noreply, %{state |
		 :money => state.money - paid,
		 :inventory => newInventory}}
  end
  
  def handle_info({:sold, productId, amount, ppu}, state) do
    newAmount = state.created[productId] - amount
    newCreated = %{state.created | productId => newAmount}
    {:noreply, %{state |
		 :money => state.money + (amount * ppu),
		 :created => newCreated}}
  end

  def handle_info(:produce, state) do
    prodId = get_best_production_option(state)
    newState = create(prodId, state)
    submit_asks(TurnMarket, newState)
    {:noreply, newState}
  end

  def handle_info(:bid, state) do
    products = Application.get_env(:eco, :products)
    maxLabour = Application.get_env(:eco, :max_labour)
    labourNeeded = maxLabour - state.labour
    
    TurnMarket.get_asks_as_list(TurnMarket)
    |> Enum.filter(fn(ask) ->
      IO.puts("class:")
      IO.puts(products[ask.product_id].class)
      products[ask.product_id].class === :food
    end)
    |> Enum.sort(fn(ask1, ask2) ->
      ask1.ppu < ask2.ppu
    end) |> place_food_bids(labourNeeded, state.money, TurnMarket)

    {:noreply, state}
  end

  def place_food_bids([ask | rest], labourNeeded, money, marketPid) when labourNeeded > 0 and money > 0 do
    foodValue = Map.get(Application.get_env(:eco, :products), ask.product_id)[:food_value]
    max = min(ask.amount, trunc(money / ask.ppu))
    IO.puts(max)
    if max > 0 do
      spend = max * ask.ppu
      bid = Bid.new(ask.id, max, self())
      IO.puts("bidding!")
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
          TurnMarket.ask(marketPid, prodId, amount, :rand.uniform*10)
    end)
  end

  #generate prefences adding up to 1
  def generate_preferences(prodIds) do
    nums = for _ <- 1..length(prodIds), do: :rand.uniform
    sum = Enum.sum(nums)

    prefs = (for n <- nums, do: n / sum)
    List.zip([prodIds, prefs])
    |> List.foldl(%{},
      fn({k, v}, prefMap) ->
	Map.put(prefMap, k, v)
      end)
  end

  def get_best_production_option(state) do
    {id, _amount} = Application.get_env(:eco, :products)
    |> Enum.map(fn({id, prod}) ->
      {id, can_create(prod, state)}
    end)
    |> Enum.sort(fn({_, v1}, {_, v2}) ->
      v1 > v2
    end) |> hd
    id
  end
  
  def can_create(product, state) do
    case product.raw do
      true ->
	       :math.floor(state.labour / product.labour_cost)
      false ->
	       0.0
    end
  end


  def create(productId, state) do
    product = (Application.get_env(:eco, :products))[productId]
    if product.raw do
      amount = :math.floor(state.labour / product.labour_cost)
      labour_cost = amount * product.labour_cost
      newAmount = amount + Map.get(state.created, productId, 0)
      %{state |
	:labour => state.labour - labour_cost,
	:created => Map.put(state.created, productId, newAmount)}
    else
      state
    end
  end

  
  def get_product_by_id(prodId) do
    (Application.get_env(:eco, :products))[prodId]
  end
end
