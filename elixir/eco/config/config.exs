# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :eco, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:eco, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config(:eco, [
  {:max_labour, 1000},
  {:number_of_bots, 50},
  {:price_sigma, 1},
  {:products,
   %{
     "chicken" => %{
       :labour_cost => 4,
       :class => :food,
       :raw => false,
       :food_value => 20,
       :deps => %{
         "bowl of snot" => 2
       }
     },
     "calories" => %{
       :labour_cost => 0.1,
       :class => :food,
       :raw => true,
       :food_value => 1
     },
     "coffee" => %{
       :labour_cost => 5,
       :class => :base,
       :raw => true
     },
     "1" => %{
       :labour_cost => 15,
       :class => :base,
       :raw => true
     },
     "2" => %{
       :labour_cost => 13,
       :class => :base,
       :raw => true
     },
     "3" => %{
       :labour_cost => 11,
       :class => :base,
       :raw => true
     },
     "4" => %{
       :labour_cost => 16,
       :class => :comodity,
       :raw => false,
       :deps => %{
         "1" => 10,
         "2" => 35
       }
     },
     "5" => %{
       :labour_cost => 20,
       :class => :comodity,
       :raw => false,
       :deps => %{
         "1" => 7,
         "3" => 20
       }
     },
     "6" => %{
       :labour_cost => 19,
       :class => :comodity,
       :raw => false,
       :deps => %{
         "2" => 3,
         "3" => 4
       }
     }
   }}
])
