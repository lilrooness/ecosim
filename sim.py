import random
import sys

from market import Market
from market import MarketCycle

from person import Person

PRODUCTION_PRICES = [10, 20, 30]

def generate_person():
  productivities = generate_productivities()
  preferences = generate_preferences()
  return Person(10000.0, productivities, preferences, 0.0, 0.0, 0.3)

def generate_productivities():
  p = [0 for n in range(len(PRODUCTION_PRICES))]
  products = choices(range(len(p)), random.randint(1, int(len(p)-1))) #a person can be able to produce up to half of the products
  for i in products:
    p[i] = round((random.random() * 4) / 10, 1) + 0.1 # generate number between 0.1 and 0.5 rounded to 1dp
  return p

#generate distribution of product preference
def generate_preferences():
  p = [random.random()*100 for n in range(len(PRODUCTION_PRICES))]
  s = sum(p)
  return [x/s for x in p]

def choices(l, n):
  return [l[i] for i in  choose_index(range(len(l)), n, [])]

def choose_index(pool, n, acc):
  if n == 0:
    return acc
  choice = random.choice(pool)
  pool.remove(choice)
  acc.append(choice)
  return choose_index(pool, n-1, acc)

if __name__ == "__main__":
  people = []
  for i in range(1000):
    people.append(generate_person())
 
  priceMatrix = []
  produceMatrix = []
  
  
  for i in range(len(people)):
    produce = people[i].produce()
    produceMatrix.append(produce)
    market_offer = people[i].offer_market(produce, Market([], []), i)
    priceMatrix.append(market_offer)

  market = Market(priceMatrix, produceMatrix)
  #consume stage
  for p in people:
    p.consume(market)

  #settle stage
  for i in range(len(people)):
    people[i].liquidity += market.cycles[market.cycle].settlement[i]
  
  market.cycle += 1
  ncycles = 50
  if len(sys.argv) > 1:
      ncycles = int(sys.argv[1])

  for cycle in range(ncycles):
    priceMatrix = []
    produceMatrix = []
    print("cycle: " + str(cycle))
    for i in range(len(people)):
     produce = people[i].produce()
     produceMatrix.append(produce)
     market_offer = people[i].offer_market(produce, market, i)
     priceMatrix.append(market_offer)

    market.new_cycle(priceMatrix, produceMatrix)
    #consume stage
    for p in people:
      p.consume(market)

    #settle stage
    for i in range(len(people)):
      people[i].liquidity += market.cycles[market.cycle].settlement[i]

    market.cycle += 1

  
  with open("price_data.txt", "w") as datafile:
    for i in range(len(market.cycles)):
      datafile.write("cycle:"+str(i)+"\n")
      for row in market.cycles[i].price_matrix:
        if row != 0:
          datafile.write(", ".join([str(x) for x in row]) + "\n")

  with open("supply_data.txt", "w") as datafile:
    for i in range(len(market.cycles)):
      datafile.write("cycle:"+str(i)+"\n")
      for row in market.cycles[i].supply_matrix:
        if row != 0:
          datafile.write(", ".join([str(x) for x in row]) + "\n")

