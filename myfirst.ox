#include <oxstd.h>

main() {
  decl m1, m2;

  m1 = unit(3);
  m1[0][0] = 2;

  m2 = <0,0,0;1,1,1>;

  print("two matrices", m1, m2);
}
