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
			 PERCIEVED_COUPON_VALUES,
       TRANS_PROB_CTL,
       TRANS_PROB_JIF,
       TRANS_PROB_PETER,
       TRANS_PROB_SKIPPY,
       TRANS_PROB_OTHER,
       N_PARAMS
  };

	enum{DELTA,ALPHA,ETA,GAMMA,Q_CTL,Q_JIF,Q_PETER,Q_SKIPPY,Q_OTHER};

	// maxmimum weeks of laundry detergent inventory
	static const decl Nwtg = 59,
                    Nconsumption = 64; // no one buys more than a years worth of laundry detergent

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
    <1.0,1.0,1.0,1.0,1.0>, 
    <0.01;0.01034117>, <0.07843137;0.09803922>, <0.5073331;0.1775556>, <0.1176471,0.1998359>, <0.04,0.06>};

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
