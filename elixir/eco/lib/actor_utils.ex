defmodule ActorUtils do
  def can_create(product, state) do
    case product.raw do
      true ->
        :math.floor(state.labour / product.labour_cost)

      false ->
        0.0
    end
  end

  def create(productId, amount, state) do
    product = Application.get_env(:eco, :products)[productId]

    if product.raw do
      creating = min(amount, :math.floor(state.labour / product.labour_cost))
      labour_cost = creating * product.labour_cost
      newAmount = creating + Map.get(state.created, productId, 0)

      %{
        state
        | :labour => state.labour - labour_cost,
          :created => Map.put(state.created, productId, newAmount)
      }
    else
      state
    end
  end

  def get_best_production_option(state) do
    {id, amount} =
      Application.get_env(:eco, :products)
      |> Enum.map(fn {id, prod} ->
        {id, can_create(prod, state)}
      end)
      |> Enum.sort(fn {_, v1}, {_, v2} ->
        v1 > v2
      end)
      |> hd

    {id, amount}
  end
end
