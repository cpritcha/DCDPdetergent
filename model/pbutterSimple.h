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
       TRANS_PROB_OTHER
  };

	enum{DELTA,ALPHA,ETA,GAMMA,Q_CTL,Q_JIF,Q_PETER,Q_SKIPPY,Q_OTHER};

	// maxmimum weeks of laundry detergent inventory
	static const decl Nwtg = 97, // 97 67
                    Nconsumption = 64; // no one buys more than a years worth of laundry detergent

	static decl purchase; // control variable
	static decl weeks_to_go, consumption, coupon_ctl, coupon_jif, coupon_peter, coupon_skippy, coupon_other; // state variables
	static decl normalization;

	static decl hat; // estimated parameters

	static InitializeStatesParams();	
	static ToggleInventoryVars();
	static ToggleCouponTransitionVars();
	static ToggleBrandPreferenceVars();

	static FirstStage();
	static SecondStage();
	static ThirdStage();

	//static Run();
	static Reachable();
				 Utility();
}
