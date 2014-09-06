// Do I need all these imports?
#import "Inventory"
#import "FiveO"
#import "DDP"
//#import "ParallelObjective"

struct DetergentEstimates {
	static decl EMax, detergent, nfxp, mle;
	static DoAll();
}

struct DetergentData : DataSet {
	DetergentData(method=0);
}

// inherits from ergodic because any state is reachable from any other state given enough time
struct Detergent : ExtremeValue {
	enum{DISCOUNT, 
			 STOCKOUT_COSTS, 
			 INVENTORY_HOLDING_COSTS, 
			 PERCIEVED_COUPON_VALUES};

	enum{DELTA,ALPHA,ETA,GAMMA,N_PARAMS};

	// maxmimum weeks of laundry detergent inventory
	static const decl NX = 120; // no one buys more than a years worth of laundry detergent

	// percieved coupon values are by brand only, not volume.
	// Don't need pars/rows for estimation
	/*
 	static const decl pars = {{0.9999, 2.0, <0.2,1.0>, <1.0, 0.8, 0.7>},
														{0.0000, 2.0, <0.1,1.0>, <1.0, 1.0, 1.0>}};
	static decl row;
	*/

	static const decl init_hat = {0.9999, <6.0,2.0>, <0.2,1.0>, <1.0,0.8,0.7>};

	static decl purchase; // control variable
	static decl weeks_to_go, consumption, coupon_ch, coupon_other, coupon_td; // state variables
	static decl normalization;

	static decl hat; // estimated parameters
	static FirstStage();
	static SecondStage();

	//static Run();
	static Reachable();
				 Utility();
}
