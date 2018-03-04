import random

PRODUCTION_PRICES = [10, 20, 30]
CYCLE = 0

class Person(object):
  def __init__(self, endowment, productivities, preferences, investmentPref, savingsPref, riskReserve):
    self.liquidity = endowment
    self.productivities = productivities
    self.preferences = preferences
    self.investmentPref = investmentPref
    self.savingsPref = savingsPref
    self.riskReserve = riskReserve

  def produce(self):
    budget = self.budget()
    spread = budget / float(sum([1 for p in self.productivities if p > 0]))
    output = []
    cost = 0
    for i in range(len(self.productivities)):
      if self.productivities[i] > 0:
        p = spread / ((1.0 - self.productivities[i]) * PRODUCTION_PRICES[i])
        output.append(int(p))
        if int(p) > 0:
          cost = cost + (spread / ((1.0 - self.productivities[i]) * PRODUCTION_PRICES[i]))
      else:
        output.append(0)
    self.liquidity = self.liquidity - cost
    return output

  def offer_market(self, produce):
    profit_margin = 0.0
    if CYCLE == 0: 
      profit_margin = 0.1 # 10 percent profit margin on all sales
    else:
      pass # TODO: Work out profit margin based on market conditions
    
    prices = []
    for i in range(len(self.productivities)):
      if produce[i] > 0:
        production_cost = ((1 - self.productivities[i]) * PRODUCTION_PRICES[i])
        price_per_unit = (production_cost * profit_margin) + production_cost
        prices.append(price_per_unit)
      else:
        prices.append(0)

    return prices

  def budget(self):
    return self.liquidity - self.liquidity*self.riskReserve

def generate_person():
  productivities = generate_productivities()
  preferences = generate_preferences()
  return Person(1000.0, productivities, preferences, 0.0, 0.0, 0.3)

def generate_productivities():
  p = [0 for n in range(len(PRODUCTION_PRICES))]
  products = choices(range(len(p)), random.randint(1, int(len(p)/2))) #a person can be able to produce up to half of the products
  for i in products:
    p[i] = round((random.random() * 4) / 10, 1) + 0.1 # generate number between 0.1 and 0.5 rounded to 1dp
  return p

def generate_preferences():
  p = [0 for n in range(len(PRODUCTION_PRICES))]
  products = choices(range(len(p)), random.randint(1, int(len(p)/2))) #a person can be able to produce up to half of the products
  for i in products:
    p[i] = round((random.random() * 4) / 10, 1) + 0.1 # generate number between 0.1 and 0.5 rounded to 1dp
  return p

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
    market_offer = people[i].offer_market(produce)
    priceMatrix.append(market_offer)

  CYCLE = CYCLE + 1
  for i in range(len(priceMatrix)):
    print(str(i)+": "+str(priceMatrix[i]))


