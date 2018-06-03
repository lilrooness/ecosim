defmodule Bot do

  defstruct(
    prefs: [],
    prods: [],
    money: 0,
    inventory: %{},
    labour: 0
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
    {:ok, %Bot{
	prefs: generate_preferences(prodIds),
	prods: prods,
	inventory: inventory,
	money: 1000,
	labour: 1000
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

  def handle_info({:sold, _productId, amount, ppu}, state) do
    money = state.money + (amount * ppu)
    {:noreply, %{state |
		 :money => money}}
  end
  
  #generate prefences adding up to 1
  def generate_preferences(prodIds) do
    nums = for _ <- 1..length(prodIds), do: :rand.uniform
    sum = Enum.sum(nums)
    prefs = for n <- nums, do: n / sum
    zipped = List.zip([prodIds, prefs])
    result = List.foldl(zipped, %{},
      fn({k, v}, prefMap) ->
	Map.put(prefMap, k, v)
      end)
    result
  end
end
