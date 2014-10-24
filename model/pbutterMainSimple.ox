#import "pbutterSimple"

/*
 * The Ox preprocessor does not support #if directive 
 * so do not refactor
 */

#ifdef LOW
const decl DR = 0.1;
#endif
#ifdef MED
const decl DR = 0.5;
#endif
#ifdef HIGH
const decl DR = 0.9;
#endif
#ifdef VHIGH
const decl DR = 0.99;
#endif 

#ifdef LINEAR
// linear utility
#ifdef COMPLEX
decl init_hat = {
	DR,
	1.0,
	<1.0>,
	<0,0,0,0,0>,
	<0.001,0.01034117>, //CTL
	<0.07843137,0.09803922>, //JIF
	<0.5073331,0.1775556>, //PETER
	<0.1176471,0.1998359>, //SKIPPY
	<0.04,0.06>  //OTHER
};

PButter::Utility() {
	decl buy = aa(purchase);

	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	cost += CV(hat[ETA])[0]*(AV(weeks_to_go)/weeks_to_go.N);

  cost -= (CV(hat[GAMMA])[0]*AV(coupon_ctl) + 
      CV(hat[GAMMA])[1]*AV(coupon_jif) +
      CV(hat[GAMMA])[2]*AV(coupon_peter) +
      CV(hat[GAMMA])[3]*AV(coupon_skippy) +
      CV(hat[GAMMA])[4]*AV(coupon_other)) * 
    (buy .? 1 .: 0);
 
	return -cost;
}
#else
decl init_hat = {
	DR,
	1.0,
	<1.0>};

PButter::Utility() {
	decl buy = aa(purchase);

	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	cost += CV(hat[ETA])[0]*(AV(weeks_to_go)/weeks_to_go.N);

	return -cost;
}
#endif
#endif

#ifdef QUAD
// quadratic utility
#ifdef COMPLEX
decl init_hat = {
	DR,
	1.0,
	<1.0,1.0>,
	<0,0,0,0,0>,
	<0.001,0.01034117>, //CTL
	<0.07843137,0.09803922>, //JIF
	<0.5073331,0.1775556>, //PETER
	<0.1176471,0.1998359>, //SKIPPY
	<0.04,0.06>  //OTHER
};

PButter::Utility() {
	decl buy = aa(purchase);

	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	cost += CV(hat[ETA])[0]*(AV(weeks_to_go)/weeks_to_go.N) + 
						CV(hat[ETA])[1]*(AV(weeks_to_go)/weeks_to_go.N)^2;

  cost -= (CV(hat[GAMMA])[0]*AV(coupon_ctl) + 
      CV(hat[GAMMA])[1]*AV(coupon_jif) +
      CV(hat[GAMMA])[2]*AV(coupon_peter) +
      CV(hat[GAMMA])[3]*AV(coupon_skippy) +
      CV(hat[GAMMA])[4]*AV(coupon_other)) * 
    (buy .? 1 .: 0);
 
	return -cost;
}
#else
decl init_hat = {
	DR,
	1.0,
	<1.0,1.0>};

PButter::Utility() {
	decl buy = aa(purchase);

	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	cost += CV(hat[ETA])[0]*(AV(weeks_to_go)/weeks_to_go.N) + 
						CV(hat[ETA])[1]*(AV(weeks_to_go)/weeks_to_go.N)^2;

	return -cost;
}
#endif
#endif

#ifdef SPLINE
// 4 knot linear spline utility
decl init_hat = {
	DR,
	1.0,
	<1.0,1.0,1.0,1.0>};

PButter::Utility() {
	decl buy = aa(purchase);

	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	decl knotw = 15;

	decl wtg = AV(weeks_to_go);
	decl //wght0 = (wtg <= knotw)*(knotw - wtg)/knotw,

			 wght1 = (wtg <= knotw)*(wtg)/knotw + 
								(wtg > knotw && wtg <= 2*knotw)*(2*knotw - wtg)/knotw,

			 wght2 = (wtg >= knotw && wtg <= 2*knotw)*(wtg - knotw)/knotw + 
								(wtg > 2*knotw && wtg <= 3*knotw)*(3*knotw - wtg)/knotw,

			 wght3 = (wtg >= 2*knotw && wtg <= 3*knotw)*(wtg - 2*knotw)/knotw +	
								(wtg > 3*knotw && wtg <= 4*knotw)*(4*knotw - wtg)/knotw,

			 wght4 = (wtg >= 3*knotw && wtg <= 4*knotw)*(wtg - 3*knotw)/knotw +
								(wtg > 4*knotw);

	cost += CV(hat[ETA])[0]*wght1 + CV(hat[ETA])[1]*wght2 + 
					CV(hat[ETA])[2]*wght3 + CV(hat[ETA])[3]*wght4;

	return -cost;
}
#endif

#ifdef STEP
decl init_hat = {
	DR,
	1.0,
	<1.0,1.1>};

PButter::Utility() {
	decl buy = aa(purchase);
	decl wtg = AV(weeks_to_go);
	decl cost = (CV(hat[ALPHA])[0])*(buy .? 0 .: 1)*(AV(weeks_to_go) > 0 ? 0 : 1);

	cost += CV(hat[ETA])[0]*(wtg >= 10 && wtg < 20) + CV(hat[ETA])[1]*(wtg >= 20);

	return -cost;
}
#endif

#ifdef COMPLEX
PButterData::PButterData(method, datafile) {
	DataSet("PeanutButter", method, TRUE);
	Observed(PButter::weeks_to_go,"wks_to_g",
					 PButter::purchase,"purch",
					 PButter::coupon_ctl,"cpn_ctl",
					 PButter::coupon_jif, "cpn_jif",
					 PButter::coupon_peter, "cpn_ptr",
					 PButter::coupon_skippy, "cpn_skp",
					 PButter::coupon_other, "cpn_oth",
					 PButter::consumption, "cons");
	IDColumn("hh_id");
	Read(datafile);
}

PButter::InitializeStatesParams() {	
	hat = new array[9];
  Initialize(1.0,Reachable,FALSE,0);

	hat[DISCOUNT] = new Determined("delta",init_hat[DISCOUNT]);
	hat[STOCKOUT_COSTS] = new Coefficients("alpha", init_hat[STOCKOUT_COSTS]);
	hat[INVENTORY_HOLDING_COSTS] = new Coefficients("eta", init_hat[INVENTORY_HOLDING_COSTS]);
	hat[PERCIEVED_COUPON_VALUES] = new Coefficients("gamma", init_hat[PERCIEVED_COUPON_VALUES]);
  
  hat[TRANS_PROB_CTL] = {
    new Probability("q_ctl1", init_hat[TRANS_PROB_CTL][0]),
    new Probability("q_ctl2", init_hat[TRANS_PROB_CTL][1])
  };
  
  hat[TRANS_PROB_JIF] = {
    new Probability("q_jif1", init_hat[TRANS_PROB_JIF][0]),
    new Probability("q_jif2", init_hat[TRANS_PROB_JIF][1])
  };

  hat[TRANS_PROB_PETER] = {
    new Probability("q_peter1", init_hat[TRANS_PROB_PETER][0]),
    new Probability("q_peter2", init_hat[TRANS_PROB_PETER][1])
  };

  hat[TRANS_PROB_SKIPPY] = {
    new Probability("q_skippy1", init_hat[TRANS_PROB_SKIPPY][0]),
    new Probability("q_skippy2", init_hat[TRANS_PROB_SKIPPY][1])
  };

  hat[TRANS_PROB_OTHER] = {
    new Probability("q_other1", init_hat[TRANS_PROB_OTHER][0]),
    new Probability("q_other2", init_hat[TRANS_PROB_OTHER][1])
  };

	SetDelta(hat[DISCOUNT]);

	purchase = new ActionVariable("purchase", 6);
  purchase.actual = <0;12;18;28;40;80.0>;
  Actions(purchase);

  consumption = new FixedEffect("consumption", Nconsumption);
  consumption.actual = (consumption.vals + 1);

  weeks_to_go = new InventoryState("weeks_to_go", Nwtg, consumption, purchase);

  coupon_ctl = new CouponState("coupon_ctl", hat[TRANS_PROB_CTL]);
  coupon_jif = new CouponState("coupon_jif", hat[TRANS_PROB_JIF]);
  coupon_peter = new CouponState(("coupon_peter"), hat[TRANS_PROB_PETER]);
  coupon_skippy = new CouponState(("coupon_skippy"), hat[TRANS_PROB_SKIPPY]);
  coupon_other = new CouponState("coupon_other", hat[TRANS_PROB_OTHER]);

  EndogenousStates(coupon_ctl, coupon_jif, coupon_peter, coupon_skippy, coupon_other, weeks_to_go, consumption);
	CreateSpaces();
}

PButter::ToggleInventoryVars() {
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
}

PButter::ToggleCouponTransitionVars() {
	hat[TRANS_PROB_CTL][0]->ToggleDoNotVary();
	hat[TRANS_PROB_CTL][1]->ToggleDoNotVary();
	hat[TRANS_PROB_JIF][0]->ToggleDoNotVary();
	hat[TRANS_PROB_JIF][1]->ToggleDoNotVary();
	hat[TRANS_PROB_PETER][0]->ToggleDoNotVary();
	hat[TRANS_PROB_PETER][1]->ToggleDoNotVary();
	hat[TRANS_PROB_SKIPPY][0]->ToggleDoNotVary();
	hat[TRANS_PROB_SKIPPY][1]->ToggleDoNotVary();
	hat[TRANS_PROB_OTHER][0]->ToggleDoNotVary();
	hat[TRANS_PROB_OTHER][1]->ToggleDoNotVary();
}

PButter::ToggleBrandPreferenceVars() {
	hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
}

PButter::FirstStage() {
	ToggleInventoryVars(); 
	ToggleBrandPreferenceVars(); 
}

PButter::SecondStage() {
	ToggleInventoryVars();
	ToggleBrandPreferenceVars();
	ToggleCouponTransitionVars();
}

PButter::ThirdStage() {
}
#else
PButterData::PButterData(method, datafile) {
	DataSet("PeanutButter", method, TRUE);
	Observed(PButter::weeks_to_go,"wks_to_g",
					 PButter::purchase,"purch",
	  			 PButter::consumption, "cons");
	IDColumn("hh_id");
	Read(datafile);
}

PButter::InitializeStatesParams() {
	rho = 1.0; // ex-post smoothing parameter
	
	hat = new array[3];
  Initialize(1.0,Reachable,FALSE,0);

	println("init_hat", init_hat);
	hat[DISCOUNT] = new Determined("delta",init_hat[DISCOUNT]);
	hat[STOCKOUT_COSTS] = new Coefficients("alpha", init_hat[STOCKOUT_COSTS]);
	hat[INVENTORY_HOLDING_COSTS] = new Coefficients("eta", init_hat[INVENTORY_HOLDING_COSTS]);
  
 	SetDelta(hat[DISCOUNT]);

	purchase = new ActionVariable("purchase", 6);
  purchase.actual = <0;12;18;28;40;80.0>;
  Actions(purchase);

  consumption = new FixedEffect("consumption", Nconsumption);
  consumption.actual = (consumption.vals + 1);

  weeks_to_go = new InventoryState("weeks_to_go", Nwtg, consumption, purchase);

  EndogenousStates(weeks_to_go, consumption);
	CreateSpaces();
}

PButter::ToggleInventoryVars() {
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
}

PButter::ToggleCouponTransitionVars() {
}

PButter::ToggleBrandPreferenceVars() {
}

PButter::FirstStage() {
	ToggleInventoryVars();  
}

PButter::SecondStage() {
	ToggleInventoryVars();
}

PButter::ThirdStage() {}
#endif

validate(args) {
	if (sizec(args) != 5) oxrunerror("DoAll() must have four arguments");
	return args;
}

main() {
	decl args = validate(arglist());

  print("\nPeanut Butter Model Starting\n\n\n\n");
  PButterEstimates::DoAll(args[1], args[2], args[3], args[4]);
}
