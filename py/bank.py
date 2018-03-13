import math

class Bank(object):
  
  def __init__(self, liquidity, fractionalReserve, baseInterestRate):
    self.baseInterestRate = baseInterestRate
    self.loans = []
    self.fractionalReserve = fractionalReserve
    self.acounts = {}
    self.liquidity = liquidity
    self.liability = 0
    self.bust = False

  def open_account(self, acountId, deposit):
    self.acounts[acountId] = deposit
    self.liquidity += deposit
    self.liability += deposit
  
  def debit(self, acountId, amount):
    if self.bust:
      return 0
    if self.acounts[acountId] > amount:
      if self.liquidity >= amount:
        self.liquidity -= amount
        self.liability -= amount
        self.acounts[acountId] -= amount
        return amount
      else:
        debitAmount = self.liquidity
        self.acounts[acountId] -= self.liquidity
        self.liability -= self.liquidity
        self.liquidity = 0
        self.bust = True
        return self.liquidity
    else:
      -1
  
  def deposit(self, acountId, amount):
    self.acounts[acountId] += amount
    self.liability += amount
    self.liquidity += amount

  def available_balance(self, acountId):
    if self.acounts[acountId] < self.liquidity:
      return self.acounts[acountId]
    else:
      return self.liquidity

  def balance(self, acountId):
    return self.acounts[acountId]


class Loan(object):
  
  def __init__(intialAmount, interestRate, debtorBankId, debtorAccountId, term):
    self.initiAmount = initialAmount
    self.interestRate = interestRate
    self.debtorBankId = debtorBankId
    self.debtorAccountId = debtorAccountId
    self.acquiredInterest = 0
    self.repaid = 0
    self.term = term
    self.complete = False

  def acquire_interest(self):
    self.acquiredInterest += self.interestRate * self.initialAmount

  def repay(self, amount):
    if repaid + amount >= self.initialAmount + self.acquiredInterest:
      self.repaid = self.initialAmount + self.acquiredInterest
      self.complete = True
    else:
      self.repaid += amount
  
  def repayable(self):
    return self.initialAmount + self.acquiredInterest - self.repaid


class CreditAgency(object):
  
  def __init__(self, peopleIds):
    self.scores = {n: CreditReport() for n in peopleIds}

  def add_debt(self, amount, personId):
    self.scores[personId].add_debt(amount)

  def remove_debt(self, amount, personId):
    self.scores[personId].remove_debt(amount)

  def loan_refused(self, personId):
    self.scores[personId].loan_refused()

  def defaulted(self, personId):
    self.scores[personId].defaulted()

class CreditReport(object):

  def __init__(self):
    self.lastCycleIncome = 0
    self.outstandingDebt = 0
    self.hasDefaulted = False
    self.refusedLoans = 0

  def add_debt(self, amount):
    self.oustandingDebt += amount

  def remove_debt(self, amount):
    self.outstandingDebt -= amount

  def loan_refused(self):
    self.refusedLoans += 1

  def defaulted(self):
    self.defaulted = True


