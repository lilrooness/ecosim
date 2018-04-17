defmodule Person do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [])
  end

  def init([id]) do
    products = for {id, _} <- Application.get_env(:eco, :products), do: id
    inventory = List.foldl(products, %{}, fn(elem, acc) -> 
      Map.put(acc, elem, 0)
    end)
    {:ok, %{
      :funds => 1000,
      :max_labour => 1000,
      :labour => 1000,
      :id => id,
      :preferences => generate_preferences(products),
      :productivities => generate_productivities(products),
      :inventory => inventory,
      :product_path => false
    }}
  end

  def handle_info(:tick, state) do
    products = Application.get_env(:eco, :products)
    newState = produce(state, products) |> auction #|> consume
    {:noreply, newState}
  end

  def consume(state) do
    labourGap = state.max_labour - state.labour
    
    state
  end

  def auction(state) do
    if state.product_path != false do
      productId = :proplists.get_value(:choice, state.product_path)
      basePrice = :proplists.get_value(:cost, state.product_path)
      amount = state.inventory[productId]
      {:ok, lotNumber} = GenServer.call(Market, {:sell, productId, amount, basePrice, self()})
      %{state | :product_path => state.product_path ++ [lot_number: lotNumber]}
    else
      state
    end
  end

  def produce(state, products) do
    lots = Market.get_lots(Market)
    
    choice = calculate_best_option(state, products)
    if can_produce_now(choice, state, products) do
      produce_product(choice, state, products)
    else
      %{state | :product_path => [choice: choice, cost: 0]}
    end
  end

  def produce_product(productId, state, products) do
    product = products[productId]
    if products[productId][:raw] do
      produced=Float.floor(state.labour/product[:labour_cost]) * state.productivities[productId]
      %{state | 
          :labour => state.labour - (product[:labour_cost] * produced),
	  :inventory => %{state.inventory | productId => state.inventory[productId] + produced},
	  :product_path => [choice: productId, cost: 0]
       }
    else
      productPath = if state.product_path != false do
        state.product_path
      else
        [choice: productId, cost: 0]
      end
      productionAmount = get_production_amount(productId, state.inventory, products, state.labour)
      deps = for dep <- products[productId][:deps], do: dep
      newInventory = List.foldl(deps, state.inventory, fn(dep, acc) ->
        id = :proplists.get_value(:id, dep)
	amount = :proplists.get_value(:amount, dep) * productionAmount
	%{acc | id => acc[id] - amount}
      end)
      
      newState = %{state | 
        :inventory => %{newInventory | productId => productionAmount + newInventory[productId]},
        :labour => state.labour - (productionAmount * product.labour_cost),
	:product_path => productPath
      }
    end
  end

  def get_production_amount(productId, inventory, products, labour) do
    if products[productId][:raw] do
      Float.floor(labour / products[productId][:labour_cost])
    else
      deps = products[productId][:deps]
      productionLimits = Enum.map(deps, fn(dep) -> 
        inventory[:proplists.get_value(:id, dep)] / :proplists.get_value(:amount, dep)
      end)
      [maxProduceable | _] = Enum.sort(productionLimits)
      min(maxProduceable, Float.floor(labour / products[productId][:labour_cost]))
    end
  end

  def can_produce_now(productId, state, products) do
    product = products[productId]
    if product.raw do
      true
    else
      has_nessecary_resources(product.deps, state.inventory)
    end
  end

  def has_nessecary_resources(productDeps, inventory) do
    has_nessecary_resources(productDeps, inventory, true)
  end

  def has_nessecary_resources(_, _, false) do
    false
  end

  def has_nessecary_resources([], _, true) do
    true
  end

  def has_nessecary_resources([dep | rest], inventory, true) do
    depId = :proplists.get_value(:id, dep)
    result = if :proplists.get_value(:amount, dep) >= inventory[depId] do
      true
    else
      false
    end
    has_nessecary_resources(rest, inventory, result)
  end

  def calculate_best_option(state, products) do
    if state.product_path != false do
      state.product_path.choice
    else
      amounts = for {id, _p} <- products,
        do: {id, get_production_amount(id, state.inventory, products, state.labour)}
      [{bestChoice, _}| _] = Enum.sort(amounts, fn({_, a}, {_, b}) -> a >= b end)
      bestChoice
    end
  end

  def generate_productivities(products) do
    numbers = for p <- products, do: {p, :rand.uniform(100)}
    sum = Enum.sum(for {_, s} <- numbers, do: s)
    List.foldl(numbers, %{}, fn({p, x}, map) ->
      Map.put(map, p, x/sum)
    end)
  end

  def generate_preferences(productIds) do
    ps = for id <- productIds, do: {id, :rand.uniform(100)}
    sum = Enum.sum((for {_, s} <- ps, do: s))
    List.foldl(ps, %{}, fn({p, x}, map) ->
      Map.put(map, p, x/sum)
    end)
  end
end


