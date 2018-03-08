import math

class Person(object):
  def __init__(self, productivities, preferences, investmentPref, savingsPref, riskReserve, bank, bankAccountId):
    self.bank = bank
    self.bankAccountId = bankAccountId
    self.productivities = productivities
    self.preferences = preferences
    self.investmentPref = investmentPref
    self.savingsPref = savingsPref
    self.riskReserve = riskReserve

  def produce(self, market, banks):
    budget = self.production_budget(banks[self.bank].available_balance(self.bankAccountId))
    spread = budget / float(sum([1 for p in self.productivities if p > 0]))
    output = []
    cost = 0
    for i in range(len(self.productivities)):
      if self.productivities[i] > 0:
        p = spread / ((1.0 - self.productivities[i]) * market.production_base_prices[i])
        output.append(int(p))
        if int(p) > 0:
          cost = cost + (spread / ((1.0 - self.productivities[i]) * market.production_base_prices[i]))
      else:
        output.append(0)
    banks[self.bank].debit(self.bankAccountId, cost)
    return output

  def offer_market(self, produce, market, idInMarket):
    prices = []
    if market.cycle == 0: 
      profit_margin = 0.1 # 10 percent profit margin on all sales
      for i in range(len(self.productivities)):
        if produce[i] > 0:
          production_cost = ((1 - self.productivities[i]) * market.production_base_prices[i])
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
          lowestPrice = (1 - self.productivities[i]) * market.production_base_prices[i]
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

  def consume(self, market, banks):
    availableSpend = self.consumer_budget(banks[self.bank].available_balance(self.bankAccountId))
    amountSpent = 0
    purchased = [0 for i in range(len(self.preferences))]
    for i in range(len(self.preferences)):
      offer = availableSpend * self.preferences[i]
      result = market.consume_product(i, offer)
      purchased[i] = result[0]
      amountSpent += result[1]
      
    banks[self.bank].debit(self.bankAccountId, amountSpent)
    return purchased

  def production_budget(self, liquidity):
    return liquidity - liquidity*self.riskReserve

  def consumer_budget(self, liquidity):
    return liquidity - liquidity*self.savingsPref


