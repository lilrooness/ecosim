import random
import sys

from market import Market
from market import MarketCycle

from person import Person

from bank import Bank
from bank import CreditAgency

from utils import choices

PRODUCTION_PRICES = [10, 10, 10]

def generate_person(bank, bankAccountId):
  productivities = generate_productivities()
  preferences = generate_preferences()
  return Person(productivities, preferences, 0.0, round(random.random(), 2), 0.3, bank, bankAccountId)

def generate_productivities():
  p = [0 for n in range(len(PRODUCTION_PRICES))]
  #a person can be able to produce up to half of the products
  products = choices(range(len(p)), random.randint(1, int(len(p)-1))) 
  for i in products:
    # generate number between 0.1 and 0.5 rounded to 1dp
    p[i] = round((random.random() * 4) / 10, 1) + 0.1 
  return p

#generate distribution of product preference
def generate_preferences():
  p = [random.random()*100 for n in range(len(PRODUCTION_PRICES))]
  s = sum(p)
  return [x/s for x in p]

if __name__ == "__main__":
  banks = [Bank(100000000, 0.1, 0.02)]
  people = []
  for i in range(1000):
    newPerson = generate_person(0, i)
    people.append(newPerson)
    banks[0].open_account(i, 10000)
 
  priceMatrix = []
  produceMatrix = []
  
  tempMarket = Market([], [], PRODUCTION_PRICES)
  for i in range(len(people)):
    produce = people[i].produce(tempMarket, banks)
    produceMatrix.append(produce)
    market_offer = people[i].offer_market(produce, tempMarket, i)
    priceMatrix.append(market_offer)

  market = Market(priceMatrix, produceMatrix, PRODUCTION_PRICES)
  #consume stage
  for p in people:
    p.consume(market, banks)

  #settle stage
  for i in range(len(people)):
    banks[people[i].bank].deposit(i, market.cycles[market.cycle].settlement[i])
  
  market.cycle += 1
  ncycles = 50
  if len(sys.argv) > 1:
      ncycles = int(sys.argv[1])

  for cycle in range(ncycles):
    priceMatrix = []
    produceMatrix = []
    print("cycle: " + str(cycle))
    for i in range(len(people)):
     produce = people[i].produce(market, banks)
     produceMatrix.append(produce)
     market_offer = people[i].offer_market(produce, market, i)
     priceMatrix.append(market_offer)

    market.new_cycle(priceMatrix, produceMatrix)
    #consume stage
    for p in people:
      p.consume(market, banks)

    #settle stage
    for i in range(len(people)):
      banks[people[i].bank].deposit(i, market.cycles[market.cycle].settlement[i])

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

