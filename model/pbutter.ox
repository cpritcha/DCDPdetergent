#include "pbutter.h"

writeLogEntry(msg) {
  decl f = fopen("/Users/calvinpritchard/Documents/out.log", "a");
  if (isfile(f)) {
    fprintln(f, msg);
    //fflush(f);
    fclose(f);
  } else print("couldn't open file");
}

PButterData::PButterData(method) {
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
	Read("../data/pbutter.dta");
}

PButterEstimates::DoAll() {
	PButter::FirstStage();
	EMax = new ValueIteration(0);
	EMax.vtoler  = 1E-1;

  pbutter = new PButterData(EMax);

	nfxp = new PanelBB("PeanutButterMLE1", pbutter,PButter::hat);
	nfxp.Volume = LOUD;
	// mle = new NelderMead(nfxp);
	mle = new BFGS(nfxp);
  mle.Volume = LOUD;
  //mle.maxiter = 15;
  //mle.tolerance = 0.2;
  nfxp->Load();

  /*
  Outcome::OnlyTransitions = TRUE;
	EMax.DoNotIterate = TRUE;
	mle -> Iterate(0);
  */


	PButter::SecondStage();
	Outcome::OnlyTransitions = FALSE;
	EMax.DoNotIterate = FALSE;
	nfxp -> ResetMax();
	mle -> Iterate(0);
	

	delete mle, nfxp, EMax;
	Bellman::Delete();
}

PButter::FirstStage() {
	hat = new array[N_PARAMS];
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
  //EndogenousStates(weeks_to_go);
  //ExogenousStates(coupon_ch, coupon_other, coupon_td);
  //GroupVariables(consumption);
	CreateSpaces();
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
  hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
}

PButter::SecondStage() {
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
  hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
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

PButter::Reachable() { return new PButter(); }

PButter::Utility() {
	// println("start utility");
  decl buy = aa(purchase);

  decl util = zeros(sizer(buy),1);

  // stockout costs
  util += (CV(hat[ALPHA])[0] +  CV(hat[ALPHA])[1]*AV(consumption))*(buy .? 0 .: 1)*
    (AV(weeks_to_go) > 0 ? 0 : 1);
  /*
  println("weeks to go: ", AV(weeks_to_go));
  println("consumption: ", AV(consumption));
  println("coupon_ch: ", AV(coupon_ch));
	println("utility1: ", util);
 */

  // inventory holding costs
	util += CV(hat[ETA])[0]*AV(weeks_to_go) + CV(hat[ETA])[1]*AV(weeks_to_go)^2;
	//println("utility2: ", util);
	
  // coupon preference weights
  util -= (CV(hat[GAMMA])[0]*AV(coupon_ctl) + 
      CV(hat[GAMMA])[1]*AV(coupon_jif) +
      CV(hat[GAMMA])[2]*AV(coupon_peter) +
      CV(hat[GAMMA])[3]*AV(coupon_skippy) +
      CV(hat[GAMMA])[4]*AV(coupon_other)) * 
    (buy .? 1 .: 0);
  //println("utility3: ", util);
  
  //writeLogEntry(sprint(util'));
  return util/10000;
}
