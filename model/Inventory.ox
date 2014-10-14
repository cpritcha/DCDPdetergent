InventoryState::next(const FeasA, const Inventory, const Bought, const Consumption) {
  //print("\n\nInventory: ", Inventory, "\n");
  
  decl vBoughtVolsFeasA = Bought.actual[FeasA[][Bought.pos]];
  decl vFeasibleInventoryStates = 
    setbounds(AV(Inventory) -1 + idiv(vBoughtVolsFeasA, AV(Consumption)), 
        Inventory.vals[0],
        Inventory.vals[sizerc(Inventory.vals)-1]);
  decl vUniqueStates = unique(vFeasibleInventoryStates);
  
  decl n = sizerc(vBoughtVolsFeasA), 
       m = sizerc(vUniqueStates);
  decl mTransProb = zeros(n,m);

  decl i=0, j=0, 
       k,
       iFeasInvState=-1, 
       iPrevFeasInvState=vFeasibleInventoryStates[0];
  for (k = 0; k < sizerc(vFeasibleInventoryStates); k++) {
    iFeasInvState = vFeasibleInventoryStates[k];
    if (iFeasInvState != iPrevFeasInvState) {
      j++;
    }
    iPrevFeasInvState = iFeasInvState;

    mTransProb[i++][j] = 1.0;
  }
//  print({vUniqueStates, mTransProb});
  return {vUniqueStates, mTransProb};
}

InventoryState::InventoryState(const L, const N, const consumption, const purchase) {
  StateVariable(L, N);
  
  this.purchase = purchase;
  this.consumption = consumption;
}

InventoryState::Transit(const FeasA) {
  return next(FeasA, this, purchase, consumption);
}

ConsumptionState::ConsumptionState(const L, const N) {
	StateVariable(L, N);
}

ConsumptionState::Transit(const FeasA) {
	decl x = v;
	return { x, ones(sizer(FeasA),1) };
}


CouponState::CouponState(const L, probs) {
  /**
   * L: label
   * probs: Array of Probability
   *          # rows = 2(# vals - 1)
   * */
  
  this.probs = probs;
  decl N = sizerc(this.probs);

  StateVariable(L, N);
}

CouponState::Transit(const FeasA) {
  decl vRows = sizer(FeasA);
  
  //println("probs: ", probs[v].v);
  decl vP = probs[v].v ~ (1-probs[v].v);
  decl mTransProb = ones(vRows, sizerc(vals));

  mTransProb .*= vP;
  //println({vals, mTransProb});
  return {vals, mTransProb};
}
