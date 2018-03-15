defmodule Products do

  @spec get_production_cost(map, list, number, number) :: {amount :: number, labourCost :: number}
  def get_production_cost(product, resources, labour, productivity) do
    labourCost = (1-productivity) * product.labour
    amountProduced = case product.deps do
      [] ->
        trunc(labour / labourCost)
      deps ->
        limitingFactors = for dep <- deps,
          do: trunc(:proplists.get_value(dep.id, resources, 0) / dep.amount)
        maxProducable = Enum.min(limitingFactors)
	Enum.min([maxProducable, trunc(labour / labourCost)])
    end
    {amountProduced, amountProduced * labourCost}
  end

  def get_production_costs(products, resources, labour, productivities) 
      when length(products) == length(productivities) do
    
    get_production_costs(products, resources, labour, productivities, [])
  end

  defp get_production_costs([], _, _, [], acc) do
    acc
  end

  defp get_production_costs([p | products], resources, labour, [{_, pv} | productivities], acc) do
    result = get_production_cost(p, resources, labour, pv)
    get_production_costs(products, resources, labour, productivities, acc ++ [{p.id, result}])
  end
end
