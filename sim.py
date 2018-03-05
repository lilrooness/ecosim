import random

PRODUCTION_PRICES = [10, 20, 30]

class Market(object):
  def __init__(self, initial_price_matrix, initial_supply_matrix):
    self.price_matrix = initial_price_matrix
    self.supply_matrix = initial_supply_matrix
    self.cycle = 0
    self.cycles = []
    self.cycles.append(MarketCycle(initial_price_matrix, initial_supply_matrix))

  def next_cycle(new_price_matrix, new_supply_matrix):
    self.cycles.append(MarkeyCycle(new_price_matrix, new_supply_matrix))
    self.cycle += 1

  # return a tuple containing amount purchased and remaining funds
  def consume_product(self, productIndex, offer):
    return self.cycles[self.cycle].consume_product(productIndex, offer)

class MarketCycle(object):
  def __init__(self, price_matrix, supply_matrix):
    self.price_matrix = price_matrix
    self.supply_matrix = supply_matrix
    self.transactions = [0 for x in range(len(PRODUCTION_PRICES))]
    self.overdemand = [0 for x in range(len(PRODUCTION_PRICES))]
    self.settlement = [0 for x in range(len(self.price_matrix))]

  def consume_product(self, productIndex, offer):
    moreAvailable = True
    amountPurchased = 0
    amountSpent = 0
    while moreAvailable == True:
      cheapestSeller = self.find_cheapest(productIndex)
      if cheapestSeller == -1:
        #no more product available
        self.overdemand[productIndex] += 1
        moreAvailable = False
        continue
      if (offer-amountSpent) < self.price_matrix[cheapestSeller][productIndex]:
        #cant afford any more product
        moreAvailable = False
        continue
      maxPurchasable = int((offer-amountSpent) / self.price_matrix[cheapestSeller][productIndex])
      if maxPurchasable <= self.supply_matrix[cheapestSeller][productIndex]:
        actualSpend = maxPurchasable * self.price_matrix[cheapestSeller][productIndex]
        amountSpent += actualSpend
        amountPurchased += maxPurchasable
        self.settlement[cheapestSeller] += actualSpend
        self.supply_matrix[cheapestSeller][productIndex] -= maxPurchasable
      else:
        actualPurchase = self.supply_matrix[cheapestSeller][productIndex]
        actualSpend = actualPurchase * self.price_matrix[cheapestSeller][productIndex]
        amountPurchased += actualPurchase
        amountSpent += actualSpend
        self.settlement[cheapestSeller] += actualSpend
        self.supply_matrix[cheapestSeller][productIndex] = 0
        moreAvailable = False
    
    result = (amountPurchased, amountSpent)
    return result

  def find_cheapest(self, productIndex):
    cheapest_value = -1
    cheapest_index = -1
    for row in range(len(self.price_matrix)):
      if cheapest_index == -1 and self.supply_matrix[row][productIndex] > 0:
        cheapest_value = self.price_matrix[row][productIndex]
        cheapest_index = row
      elif cheapest_value > self.price_matrix[row][productIndex] and self.supply_matrix[row][productIndex] > 0:
        cheapest_index = row
        cheapest_value = self.price_matrix[row][productIndex]
    return cheapest_index

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

  def offer_market(self, produce, market, idInMarket):
    prices = []
    if market.cycle == 0: 
      profit_margin = 0.1 # 10 percent profit margin on all sales
      for i in range(len(self.productivities)):
        if produce[i] > 0:
          production_cost = ((1 - self.productivities[i]) * PRODUCTION_PRICES[i])
          price_per_unit = (production_cost * profit_margin) + production_cost
          prices.append(price_per_unit)
        else:
          prices.append(0)
    else:
      prevCycle = market.cycles[market.cycle-1]
      for i in range(len(self.productivities)):
        if produce[i] > 0:
          pass
        elif prevCycle.overdemand[i] > 0:
          prices.append(prevCycle.price_matrix[idInMarket][i] * 1.1) # if demand outstriped supply, bump price by 10 percent
        elif prevCycle.settlement[idInMarket] == 0:
          prices.append(prevCycle.price_matrix[idInMarket][i] * 0.9) # if no sales were made, reduce price by 10 percent
            
    return prices

  def consume(self, market):
    amountSpent = 0
    purchased = [0 for i in range(len(self.preferences))]
    for i in range(len(self.preferences)):
      offer = self.liquidity * self.preferences[i]
      result = market.consume_product(i, offer)
      purchased[i] = result[0]
      amountSpent += result[1]
      
    self.liquidity -= amountSpent
    return purchased

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

  for cycle in range(3):
    priceMatrix = []
    produceMatrix = []
    print("cycle: " + str(cycle))
    for i in range(len(people)):
     produce = people[i].produce()
     produceMatrix.append(produce)
     market_offer = people[i].offer_market(produce, market, i)
     priceMatrix.append(market_offer)

    #consume stage
    for p in people:
      p.consume(market)

    #settle stage
    for i in range(len(people)):
      people[i].liquidity += market.cycles[market.cycle].settlement[i]
     



