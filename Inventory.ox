InventoryState::InventoryState(const L, const N, const consumption, const purchase) {
  StateVariable(L, N);
  
  this.purchase = purchase;
  this.consumption = consumption;
}

InventoryState::Transit(const FeasA) {
  decl atom  = setbounds(actual[v] - 1 + floor(purchase.actual[purchase.v]/AV(consumption)),
                    actual[0], actual[N-1]);
  return { atom, <1.0> };
}

ConsumptionState::ConsumptionState(const L, const N) {
	StateVariable(L, N);
}

ConsumptionState::Transit(const FeasA) {
	decl x = actual[v];
	return { x, <1.0> };
}

ConsumptionState::Update() {
  actual = (vals + 1) * 5;
}
