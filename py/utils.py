import random

def choices(l, n):
  return [l[i] for i in  choose_index(list(range(len(l))), n, [])]

def choose_index(pool, n, acc):
  if n == 0:
    return acc
  choice = random.choice(pool)
  pool.remove(choice)
  acc.append(choice)
  return choose_index(pool, n-1, acc)


