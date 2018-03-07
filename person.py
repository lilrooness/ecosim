PRODUCTION_PRICES = [10, 20, 30]

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
      lastCycleProfits = prevCycle.settlement[idInMarket]
      newPrice = 0
      for i in range(len(self.productivities)):
        if produce[i] == 0:
          prices.append(0)
          continue
        elif prevCycle.overdemand[i] > 0:
          # if demand outstriped supply, bump price by 10 percent
          newPrice = prevCycle.price_matrix[idInMarket][i] * 1.1
        elif prevCycle.settlement[idInMarket] == 0:
          # if no sales were made, reduce price by 10 percent
          newPrice = prevCycle.price_matrix[idInMarket][i] * 0.9
        elif prevCycle.find_cheapest(i) != idInMarket:
          cheapestPrice = prevCycle.find_cheapest(i)
          lowestPrice = (1 - self.productivities[i]) * PRODUCTION_PRICES[i]
          difference = cheapestPrice - lowestPrice
          if difference > (lowestPrice * 0.1):
            newPrice = cheapestPrice * 0.9
          else:
            newPrice = lowestPrice
        #if profits are down
        elif market.cycle > 1 and market.cycles[market.cycle-2].settlement[idInMarket] > lastCycleProfits:
          newPrice = prevCycle.price_matrix[idInMarket][i] * 0.9
        else:
          newPrice = prevCycle.price_matrix[idInMarket][i]
        if newPrice > 0:
          prices.append(newPrice)
        else:
          prices.append(prevCycle.price_matrix[idInMarket][i])

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


