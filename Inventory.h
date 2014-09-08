#import "DDP"

struct InventoryState : NonRandom {
  decl weeks_to_go, purchase, consumption;
  InventoryState(const L, const N, const purchase, const consumption);
  Transit(const FeasA);
  static next(const FeasA, const Inventory, const Bought, const Consumption);
}

struct ConsumptionState : NonRandom {
	ConsumptionState(const L, const N);
	Transit(const FeasA);
  //Update();
}	
