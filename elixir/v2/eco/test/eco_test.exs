defmodule EcoTest do
  use ExUnit.Case

  test "Person generate preferences" do
    productIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    preferences = for {_, p} <- Person.generate_preferences(productIds), do: p
    sum = Enum.sum(preferences)
    assert sum == 1
    assert length(preferences) == length(productIds)
  end

  test "Person produces some product" do
    products = Application.get_env(:eco, :products)
    productIds = for {id, _} <- products, do: id
    testState = %{
      :funds => 1000,
      :labour => 1000,
      :id => 0,
      :preferences => Person.generate_preferences(productIds),
      :productivities => Person.generate_productivities(productIds),
      :inventory => %{
        1 => 10,
	2 => 35,
	3 => 0,
	4 => 0,
	5 => 0,
	6 => 0
      }
    }

    newState = Person.produce_product(4, testState, products)
    assert newState.labour == 984
    assert newState.inventory[4] == 1
  end

  test "Person get production amount" do
    products = Application.get_env(:eco, :products)
    productIds = for {id, _} <- products, do: id
    testState = %{
      :funds => 1000,
      :labour => 1000,
      :id => 0,
      :preferences => Person.generate_preferences(productIds),
      :productivities => Person.generate_productivities(productIds),
      :inventory => %{
        1 => 10,
	2 => 35,
	3 => 0,
	4 => 0,
	5 => 0,
	6 => 0
      }
    }

    assert Person.get_production_amount(4, testState.inventory, products, testState.labour) == 1
  end

  test "Person check has nessecary resources" do
    productIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    testState = %{
      :funds => 1000,
      :labour => 1000,
      :id => 0,
      :preferences => Person.generate_preferences(productIds),
      :productivities => Person.generate_productivities(productIds),
      :inventory => %{
        1 => 10,
	2 => 35,
	3 => 0,
	4 => 0,
	5 => 0,
	6 => 0
      }
    }
    assert Person.can_produce_now(1, testState, Application.get_env(:eco, :products)) == true
    assert Person.can_produce_now(2, testState, Application.get_env(:eco, :products)) == true
    assert Person.can_produce_now(3, testState, Application.get_env(:eco, :products)) == true
    assert Person.can_produce_now(4, testState, Application.get_env(:eco, :products)) == true
    assert Person.can_produce_now(5, testState, Application.get_env(:eco, :products)) == false
    assert Person.can_produce_now(6, testState, Application.get_env(:eco, :products)) == false
  end
end
