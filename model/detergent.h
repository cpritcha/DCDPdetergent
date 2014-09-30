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
			 PERCIEVED_COUPON_VALUES,
       TRANS_PROB_CH,
       TRANS_PROB_OTHER,
       TRANS_PROB_TD,
       N_PARAMS
  };

	enum{DELTA,ALPHA,ETA,GAMMA,Q_CH,Q_OTHER,Q_TD};

	// maxmimum weeks of laundry detergent inventory
	static const decl Nwtg = 118,
                    Nconsumption = 53; // no one buys more than a years worth of laundry detergent

	// percieved coupon values are by brand only, not volume.
	// Don't need pars/rows for estimation
	/*
 	static const decl pars = {{0.9999, 2.0, <0.2,1.0>, <1.0, 0.8, 0.7>},
														{0.0000, 2.0, <0.1,1.0>, <1.0, 1.0, 1.0>}};
	static decl row;
	*/

	static const decl init_hat = {
    0.9, 
    <2.0,5.0>, 
    <0.1,0.2>, 
    <1.0,1.5,5.0>, 
    <0.84526;0.46132>, <0.21632;0.10668>, <0.72663;0.70503>};

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
