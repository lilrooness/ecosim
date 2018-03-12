import matplotlib.pyplot as plt

priceCycles = []
supplyCycles = []

with open("price_data.txt", "r") as datafile:
    cycleIndex = -1
    for line in datafile.readlines():
        if not line.startswith("cycle:"):
            priceCycles[cycleIndex].append([float(x) for x in line.split(",")])
        else:
            priceCycles.append([])
            cycleIndex += 1

with open("supply_data.txt", "r") as datafile:
    cycleIndex = -1
    for line in datafile.readlines():
        if not line.startswith("cycle:"):
            supplyCycles[cycleIndex].append([float(x) for x in line.split(",")])
        else:
            supplyCycles.append([])
            cycleIndex += 1


def generate_price_plots(priceCycles, fig):
  averages = []
  ranges = [] 
  maxPrice = []
  minPrice = []
  standardDeviations = []
  productPriceVectors = []
  
  for cycle in priceCycles:
      row = [0 for x in cycle[0]]
      rangeRow = [0 for x in cycle[0]]
      priceVectorRow = [0 for x in cycle[0]]
      maxPriceRow = [0 for x in cycle[0]]
      minPriceRow = [0 for x in cycle[0]]

      for i in range(len(row)):
          sumList = []
          prices = []
          for offerRow in cycle:
              if offerRow[i] > 0:
                  sumList.append(offerRow[i])
                  prices.append(offerRow[i])
          if len(sumList) == 0:
              row[i] = 0
              rangeRow[i] = 0
              maxPriceRow[i] = 0
              minPriceRow[i] = 0
          else:
              row[i] = sum(sumList) / float(len(sumList))
              rangeRow[i] = max(prices) - min(prices)
              priceVectorRow[i] = prices
              maxPriceRow[i] = max(prices)
              minPriceRow[i] = min(prices)
  
      averages.append(row)
      ranges.append(rangeRow)
      maxPrice.append(maxPriceRow)
      minPrice.append(minPriceRow)
      productPriceVectors.append(priceVectorRow)
  
  
  
  plt.figure(fig)
  plt.subplot(221)
  plt.title("average price of products")
  for i in range(len(averages[0])):
      plt.plot([x for x in range(len(priceCycles))], [a[0] for a in averages])
      plt.boxplot([a[0] for a in productPriceVectors])
      plt.plot([x for x in range(len(priceCycles))], [a[0] for a in maxPrice])

  
  plt.subplot(222)
  plt.title("max price of products")
  for i in range(len(maxPrice[0])):
      plt.plot([x for x in range(len(priceCycles))], [a[i] for a in maxPrice])
  
  plt.subplot(223)
  plt.title("min price of products")
  for i in range(len(minPrice[0])):
      plt.plot([x for x in range(len(priceCycles))], [a[i] for a in minPrice])

  plt.figure(fig)
  plt.subplot(224)
  plt.title("average price of products")
  for i in range(len(averages[0])):
      plt.errorbar([x for x in range(len(priceCycles))], [a[i] for a in averages], yerr=[a[i] for a in ranges])


supplyPerCycle = []

for cycle in supplyCycles:
    row = [0 for i in range(len(cycle[0]))]
    for i in range(len(row)):
        row[i] = sum([a[i] for a in cycle])
    supplyPerCycle.append(row)

plt.figure(1)
plt.title("supply")
for i in range(len(supplyPerCycle[0])):
    plt.plot([x for x in range(len(supplyCycles))], [y[i] for y in supplyPerCycle])

generate_price_plots(priceCycles, 2)


plt.show()
