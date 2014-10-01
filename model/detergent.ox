#include "detergent.h"

writeLogEntry(msg) {
  decl f = fopen("/Users/calvinpritchard/Documents/out.log", "a");
  if (isfile(f)) {
    fprintln(f, msg);
    //fflush(f);
    fclose(f);
  } else print("couldn't open file");
}

#ifdef DEBUG
prettyprint(label, x) {
  decl sep = "\n--------------------------\n";
  print(label,sep,x,sep,"\n\n");
}
#else
prettyprint(label, x) {}
#endif

DetergentData::DetergentData(method) {
	DataSet("Detergent", method, TRUE);
	Observed(Detergent::weeks_to_go,"wks_to_g",
					 Detergent::purchase,"purch",
					 Detergent::coupon_ch,"cpn_ch",
					 Detergent::coupon_other, "cpn_oth",
					 Detergent::coupon_td, "cpn_td",
					 Detergent::consumption, "cons");
	IDColumn("hh_id");
	Read("../data/full.dta");
}

DetergentEstimates::DoAll() {
	Detergent::FirstStage();
	EMax = new ValueIteration(0);
	EMax.vtoler  = 1E-1;

  detergent = new DetergentData(EMax);

	nfxp = new PanelBB("DetergentMLE1", detergent,Detergent::hat);
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


	Detergent::SecondStage();
	Outcome::OnlyTransitions = FALSE;
	EMax.DoNotIterate = FALSE;
	nfxp -> ResetMax();
	mle -> Iterate(0);
	

	delete mle, nfxp, EMax;
	Bellman::Delete();
}

Detergent::FirstStage() {
	hat = new array[N_PARAMS];
  Initialize(1.0,Reachable,FALSE,0);

	hat[DISCOUNT] = new Determined("delta",init_hat[DISCOUNT]);
	hat[STOCKOUT_COSTS] = new Coefficients("alpha", init_hat[STOCKOUT_COSTS]);
	hat[INVENTORY_HOLDING_COSTS] = new Coefficients("eta", init_hat[INVENTORY_HOLDING_COSTS]);
	hat[PERCIEVED_COUPON_VALUES] = new Coefficients("gamma", init_hat[PERCIEVED_COUPON_VALUES]);
  
  hat[TRANS_PROB_CH] = {
    new Probability("q_ch1", init_hat[TRANS_PROB_CH][0]),
    new Probability("q_ch2", init_hat[TRANS_PROB_CH][1])
  };
  
  hat[TRANS_PROB_OTHER] = {
    new Probability("q_other1", init_hat[TRANS_PROB_OTHER][0]),
    new Probability("q_other2", init_hat[TRANS_PROB_OTHER][1])
  };
  
  hat[TRANS_PROB_TD] = {
    new Probability("q_td1", init_hat[TRANS_PROB_TD][0]),
    new Probability("q_td2", init_hat[TRANS_PROB_TD][1])
  };

	SetDelta(hat[DISCOUNT]);

	purchase = new ActionVariable("purchase", 7);
  purchase.actual = <0;17;42;72;127;227;400.0>;
  Actions(purchase);
	prettyprint("Purchases", purchase);

  consumption = new FixedEffect("consumption", Nconsumption);
  consumption.actual = (consumption.vals + 4);
  prettyprint("Consumption", consumption);

  weeks_to_go = new InventoryState("weeks_to_go", Nwtg, consumption, purchase);
  prettyprint("Weeks Left", weeks_to_go);

  coupon_ch = new CouponState("coupon_ch", hat[TRANS_PROB_CH]);
  prettyprint("Coupon (Cheer)", coupon_ch);

  coupon_other = new CouponState("coupon_other", hat[TRANS_PROB_OTHER]);
  prettyprint("Coupon (Other)", coupon_other);

  coupon_td = new CouponState("coupon_td", hat[TRANS_PROB_TD]);
  prettyprint("Coupon (Tide)", coupon_td);
  
  EndogenousStates(coupon_ch, coupon_other, coupon_td, weeks_to_go, consumption);
  //EndogenousStates(weeks_to_go);
  //ExogenousStates(coupon_ch, coupon_other, coupon_td);
  //GroupVariables(consumption);
	CreateSpaces();
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
  hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
}

Detergent::SecondStage() {
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
  hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
	hat[TRANS_PROB_CH][0]->ToggleDoNotVary();
	hat[TRANS_PROB_CH][1]->ToggleDoNotVary();
  hat[TRANS_PROB_OTHER][0]->ToggleDoNotVary();
	hat[TRANS_PROB_OTHER][1]->ToggleDoNotVary();
  hat[TRANS_PROB_TD][0]->ToggleDoNotVary();
	hat[TRANS_PROB_TD][1]->ToggleDoNotVary();
}

Detergent::Reachable() { return new Detergent(); }

Detergent::Utility() {
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
  util -= (CV(hat[GAMMA])[0]*AV(coupon_ch) + CV(hat[GAMMA])[1]*AV(coupon_other) +CV(hat[GAMMA])[2]*AV(coupon_td)) * 
    (buy .? 1 .: 0);
  //println("utility3: ", util);
  
  //writeLogEntry(sprint(util'));
  return util/10000;
}
