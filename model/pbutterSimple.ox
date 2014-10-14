#include "pbutterSimple.h"

decl logfile;

decl maxutil = -.Inf,
		 minutil = .Inf;

writeToFile(fname, msg) {
  decl f = fopen(fname, "a");
  if (isfile(f)) {
    fprintln(f, msg);
    fclose(f);
  } else print("couldn't open file");
}

writeLogEntry(msg) {
	writeToFile(logfile, msg);
}

aconfint(resultsfile, solution, invhessian, level) {
	// calculates a two sided asymptotic normal confidence interval
	writeToFile(resultsfile, "parameters initial:\n" + sprint(solution));
	
	solution = solution[1:(sizer(solution)-1)]; // get rid of the discount rate parameter
  writeToFile(resultsfile, "hessian:\n" + sprint(invhessian)); 
	writeToFile(resultsfile, "parameters:\n" + sprint(solution));
	
	decl n = sizec(invhessian),
			 m = sizer(invhessian);
	writeToFile(resultsfile, "n: " + sprint(n) + "  m: " + sprint(m));

	if (n != m) oxrunerror("invhessian nrows != ncols");
	if (n != sizer(solution)) oxrunerror("solution nrows != invhessian nrows");

	level = (1+level)/2; 

	decl confidence;
	decl confidenceMat = zeros(n,2);
	decl i;
	for (i = 0; i < n; i++) {
		confidence = quann(level)*invhessian[i][i];
		confidenceMat[i][1] = solution[i] + confidence;
		confidenceMat[i][0] = solution[i] - confidence;
	}
	writeToFile(resultsfile, "confidence interval:\n" + sprint(confidenceMat));
}

PButterData::PButterData(method, datafile) {
	DataSet("PeanutButter", method, TRUE);
	Observed(PButter::weeks_to_go,"wks_to_g",
					 PButter::purchase,"purch",
	  			 PButter::consumption, "cons");
	IDColumn("hh_id");
	Read(datafile);
}

PButterEstimates::DoAll(_datafile, _logfile, _resultsfile, _savefile) {
	logfile = _logfile;

	PButter::InitializeStatesParams();
	EMax = new ValueIteration(0);
	EMax.vtoler  = 1E-1;

  pbutter = new PButterData(EMax, _datafile);

	nfxp = new PanelBB("PeanutButterMLE1", pbutter,PButter::hat);
	nfxp.Volume = LOUD;
	nfxp.fname = _savefile;

  mleNM = new BFGS(nfxp); //new NelderMead(nfxp);
  mleNM.Volume = LOUD;
  mleNM.maxiter = 1;

	mleBHHH = new BHHH(nfxp);
	mleBHHH.Volume = LOUD;
	mleBHHH.maxiter = 1;
  
	nfxp->Load(_savefile);
	//nfxp->Save();
	println("\nFirst Stage");
	PButter::FirstStage();
	// first stage estimated in R	
	//Outcome::OnlyTransitions = TRUE;
	//EMax.DoNotIterate = TRUE;
	//mleNM -> Iterate(0);
	
	println("\nSecond Stage");
	PButter::SecondStage();
	Outcome::OnlyTransitions = FALSE;
	EMax.DoNotIterate = FALSE;
	nfxp -> ResetMax();
	mleNM -> Iterate(0);	

	println("\nThird Stage");
	PButter::ThirdStage();
	// Perform one iteration for all parameters
	// to get variance/covariance matrix
	nfxp -> ResetMax();
	mleBHHH -> Iterate(0);

	nfxp->Save(_savefile);

	aconfint(_resultsfile, mleBHHH.O.cur.X, invert(mleBHHH.OC.H), 0.95);

	delete mleNM, mleBHHH, nfxp, EMax;
	Bellman::Delete();
}

PButter::InitializeStatesParams() {	
	hat = new array[N_PARAMS];
  Initialize(1.0,Reachable,FALSE,0);

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

PButter::FirstStage() {
	ToggleInventoryVars();  
}

PButter::SecondStage() {
	ToggleInventoryVars();
}

PButter::ThirdStage() {
}

PButter::Reachable() { return new PButter(); }

PButter::Utility() {
	// println("start utility");
  decl buy = aa(purchase);

  decl util = zeros(sizer(buy),1);

  // stockout costs
  util += (CV(hat[ALPHA])[0] +  CV(hat[ALPHA])[1]*log(AV(consumption) + 1))*(buy .? 0 .: 1)*
    (AV(weeks_to_go) > 0 ? 0 : 1);
  
  // inventory holding costs
	util += CV(hat[ETA])[0]*log(AV(weeks_to_go) + 1);
  
	decl normalization = -1e-2*(log(Nwtg)*CV(hat[ETA])[0] + log(Nconsumption)*CV(hat[ALPHA])[1])/2;

	if (util > maxutil) {
		writeLogEntry("maxutil: " + sprint(util) + "\t\tnormalization: " + sprint(normalization));
		maxutil = util;
	}
	if (util < minutil) {
		writeLogEntry("minutil: " + sprint(util) + "\t\tnormalization: " + sprint(normalization));
		minutil = util;
	}
  //writeLogEntry(sprint(util'));
  return -util + normalization;
}
