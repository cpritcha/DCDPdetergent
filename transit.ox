#import "Inventory"

next(const FeasA, const Inventory, const Bought, const Consumption) {
  decl vBoughtVolsFeasA = Bought.actual[FeasA[][Bought.pos]];
  decl vFeasibleInventoryStates = 
    setbounds(AV(Inventory) -1 + round(vBoughtVolsFeasA/AV(Consumption)), 
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
  return {vUniqueStates, mTransProb};
}

main() {
  decl Consumption = new ConsumptionState("cons", 11);
  Consumption.actual = (Consumption.vals + 1)*5;

  decl Bought = new ActionVariable("bought", 7);
  Bought.actual = <0;17;42;72;127;227;400.0>;

  decl Inventory = new InventoryState("inv", 115, Bought, Consumption);
  Bought.pos = 0;
  Consumption.v = 5; // (5+1)*5 = 30

  decl FeasA = Bought.vals';

  Inventory.v = 0;
  print("\nLow inventory (weeks_to_go = 0)\n");
  print(next(FeasA, Inventory, Bought, Consumption));

  Inventory.v = 20;
  print("\nMedium inventory (weeks_to_go = 20)\n");
  print(next(FeasA, Inventory, Bought, Consumption));

  Inventory.v = 114;
  print("\nHigh inventory (weeks_to_go = 114)\n");
  print(next(FeasA, Inventory, Bought, Consumption));
}
