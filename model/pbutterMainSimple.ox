#import "pbutterSimple"

validate(args) {
	if (sizec(args) != 5) oxrunerror("DoAll() must have four arguments");
	return args;
}

main() {
	decl args = validate(arglist());

  print("\nPeanut Butter Model Starting\n\n\n\n");
  PButterEstimates::DoAll(args[1], args[2], args[3], args[4]);
}
