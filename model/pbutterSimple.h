#import "Inventory"
#import "FiveO"
#import "DDP"

struct PButterEstimates {
	static decl EMax, pbutter, nfxp, mleNM, mleBHHH;
	static DoAll(_datafile, _logfile, _resultfile, _savefile);
}

struct PButterData : DataSet {
	PButterData(method, datafile);
}

// inherits from ergodic because any state is reachable from any other state given enough time
struct PButter : ExtremeValue {
	enum{DISCOUNT, 
			 STOCKOUT_COSTS, 
			 INVENTORY_HOLDING_COSTS, 
       N_PARAMS
  };

	enum{DELTA,ALPHA,ETA};

	// maxmimum weeks of laundry detergent inventory
	static const decl Nwtg = 59,
                    Nconsumption = 64; // no one buys more than a years worth of laundry detergent

	static const decl init_hat = {
    0.9, 
    <2.0,5.0>, 
    <0.1>}; 

	static decl purchase; // control variable
	static decl weeks_to_go, consumption, coupon_ctl, coupon_jif, coupon_peter, coupon_skippy, coupon_other; // state variables
	static decl normalization;

	static decl hat; // estimated parameters

	static InitializeStatesParams();	
	static ToggleInventoryVars();
	static ToggleCouponTransitionVars();

	static FirstStage();
	static SecondStage();
	static ThirdStage();

	//static Run();
	static Reachable();
				 Utility();
}
