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
    newInventory = %{state.inventory | :productId => newAmount}
    {:noreply, %{state |
		 :money => state.money - paid,
		 :inventory => newInventory}}
  end
  
  def handle_info({:sold, productId, amount, ppu}, state) do
    money = state.money + (amount * ppu)
    newAmount = state.created[productId] - amount
    newCreated = %{state.created | productId => newAmount}
    {:noreply, %{state |
		 :money => money,
		 :created => newCreated}}
  end

  def handle_info(:produce, state) do
    prodId = get_best_production_option(state)
    newState = create(prodId, state)
    submit_asks(TurnMarket, newState)
    {:noreply, newState}
  end

  def submit_asks(marketPid, state) do
    state.created
    |> Enum.each(fn({prodId, amount}) ->
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
