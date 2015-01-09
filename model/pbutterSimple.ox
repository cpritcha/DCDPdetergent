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

PButterEstimates::DoAll(_datafile, _logfile, _resultsfile, _savefile) {
	logfile = _logfile;

	PButter::InitializeStatesParams();
	EMax = new ValueIteration(0);//KeaneWolpin(0.2); //ValueIteration(0);
	EMax.vtoler  = 1E-1;

  pbutter = new PButterData(EMax, _datafile);

	nfxp = new PanelBB("PeanutButterMLE1", pbutter,PButter::hat);
	nfxp.Volume = LOUD;
	nfxp.fname = _savefile;

  mleNM = new NelderMead(nfxp); //new NelderMead(nfxp);
  mleNM.Volume = LOUD;

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

	aconfint(_resultsfile, mleNM.O.cur.X, invert(nfxp.cur.H), 0.95);

	delete mleNM, mleBHHH, nfxp, EMax;
	Bellman::Delete();
}


PButter::Reachable() { return new PButter(); }
