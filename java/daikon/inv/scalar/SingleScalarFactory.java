package daikon.inv.scalar;

import daikon.*;

// I think this is likely to disappear, except possibly as a place to keep
// common data like minimum and maximum.

public class SingleScalarFactory {

  // Adds the appropriate new Invariant objects to the specified Invariants
  // collection.
  public static void instantiate(PptSlice ppt, int pass) {

    // Not really the right place for this test
    if (!(ppt.var_infos[0].type.dimensions() == 0))
      return;

    if (pass == 1) {
      OneOfScalar.instantiate(ppt);
    } else if (pass == 2) {
      LowerBound.instantiate(ppt);
      Modulus.instantiate(ppt);
      NonModulus.instantiate(ppt);
      NonZero.instantiate(ppt);
      UpperBound.instantiate(ppt);
    }
  }

  private SingleScalarFactory() {
  }

}
