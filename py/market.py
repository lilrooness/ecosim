
class Market(object):
  def __init__(self, initial_price_matrix, initial_supply_matrix, production_base_prices):
    self.production_base_prices = production_base_prices
    self.price_matrix = initial_price_matrix
    self.supply_matrix = initial_supply_matrix
    self.cycle = 0
    self.cycles = []
    self.cycles.append(MarketCycle(initial_price_matrix, initial_supply_matrix, self.production_base_prices))

  def new_cycle(self, new_price_matrix, new_supply_matrix):
    self.cycles.append(MarketCycle(new_price_matrix, new_supply_matrix, self.production_base_prices))

  # return a tuple containing amount purchased and remaining funds
  def consume_product(self, productIndex, offer):
    return self.cycles[self.cycle].consume_product(productIndex, offer)

class MarketCycle(object):
  def __init__(self, price_matrix, supply_matrix, production_base_prices):
    self.production_base_prices = production_base_prices
    self.price_matrix = price_matrix
    self.supply_matrix = supply_matrix
    self.transactions = [0 for x in range(len(self.production_base_prices))]
    self.overdemand = [0 for x in range(len(self.production_base_prices))]
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


