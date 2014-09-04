#import "DDP"

struct InventoryState : Autonomous {
  decl weeks_to_go, purchase, consumption;
  InventoryState(const L, const N, const purchase, const consumption);
  Transit(const FeasA);
}

struct ConsumptionState : Autonomous {
	ConsumptionState(const L, const N);
	Transit(const FeasA);
  Update();
}	
