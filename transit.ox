#import "Inventory"

vDblToInt(v) {
  decl i, n = sizerc(v), vNew = zeros(n);
  for (i = 0; i < n; i++) {
    vNew[i] = int(vec(v)[i][0]);
  }
  return vNew;
}

next(const FeasA, const Inventory, const Bought, const Consumption) {
  decl vBoughtVolsFeasA = Bought.actual[FeasA[][Bought.pos]];
  decl vFeasibleInventoryStates = 
    setbounds(AV(Inventory) -1 + round(vBoughtVolsFeasA/AV(Consumption)), 
        Inventory.vals[0],
        Inventory.vals[sizerc(Inventory.vals)-1]);
  decl vUniqueStates = unique(vFeasibleInventoryStates);
  print("\nvUV:\n", vUniqueStates); 
  print("\nV:\n", int(vUniqueStates[0]));
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
  return {vUniqueStates, mTransProb};
}

main() {
  decl Consumption = new ConsumptionState("cons", 11);
  Consumption.actual = (Consumption.vals + 1)*5;

  decl Bought = new ActionVariable("bought", 7);
  Bought.actual = <0;17;42;72;127;227;400.0>;

  decl Inventory = new InventoryState("inv", 115, Bought, Consumption);
  Inventory.v = 114;
  Bought.pos = 0;
  Consumption.v = 5;

  decl FeasA = Bought.vals';

  print(next(FeasA, Inventory, Bought, Consumption));

  print(range(0,10));
  print(1~2);
}
