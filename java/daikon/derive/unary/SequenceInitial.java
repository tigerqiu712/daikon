package daikon.derive.unary;
import daikon.*;
import daikon.derive.*;
import daikon.derive.binary.*;
import utilMDE.*;

// This represents a sequence element at a particular offset (such as
// first, second, penultimate, last).

// originally from pass1.
public final class SequenceInitial extends UnaryDerivation {

  public final int index;       // negative if counting from end
                                // typically 0,1,-1, or -2
  // array length required for the subscript to be meaningful:  (ie, 1 or 2)
  final int minLength;

  public SequenceInitial(VarInfo vi, int index) {
    super(vi);
    this.index = index;
    if (index < 0)
      minLength = -index;
    else
      minLength = index+1;
  }

  public VarInfo seqvar() {
    return base;
  }

  public static boolean applicable(VarInfo vi) {
    Assert.assert(vi.rep_type == ProglangType.INT_ARRAY);
    // For now, applicable if not a derived variable; a better test is if
    // not a prefix subsequence (sequence slice) we have added.
    if (vi.derived != null) {
      Assert.assert((vi.derived instanceof SequenceScalarSubsequence) ||
		    (vi.derived instanceof ScalarSequencesIntersection) ||
		    (vi.derived instanceof ScalarSequencesUnion));
      return false;
    }

    if (vi.isConstant() && vi.constantValue() == null) {
      return false;
    }

    VarInfo lengthvar = vi.sequenceSize();
    if (lengthvar != null && lengthvar.isConstant()) {
      long length_constant = ((Long) lengthvar.constantValue()).longValue();
      if (length_constant == 0) {
        return false;
      }
    }

    return true;
  }

  public ValueAndModified computeValueAndModified(ValueTuple vt) {
    int source_mod = base.getModified(vt);
    if (source_mod == ValueTuple.MISSING)
      return ValueAndModified.MISSING;
    Object val = base.getValue(vt);
    if (val == null)
      return ValueAndModified.MISSING;
    if (base.rep_type == ProglangType.INT_ARRAY) {
      long[] val_array = (long[])val;
      if (val_array.length < minLength)
        return ValueAndModified.MISSING;
      int real_index = (index<0 ? val_array.length + index : index);
      return new ValueAndModified(Intern.internedLong(val_array[real_index]), source_mod);
    } else {
      Object[] val_array = (Object[])val;
      if (val_array.length < minLength)
        return ValueAndModified.MISSING;
      int real_index = (index<0 ? val_array.length + index : index);
      return new ValueAndModified(val_array[real_index], source_mod);
    }
  }

  protected VarInfo makeVarInfo() {

    VarInfoName name = base.name.applySubscript(VarInfoName.parse(String.valueOf(index)));
//      String name = BinaryDerivation.addSubscript(base.name, "" + index);
//      String esc_index = ((index < 0)
//                          ? (base.esc_name + ".length" + index)
//                          : "" + index);
//      String esc_name = BinaryDerivation.addSubscript_esc(base.esc_name, esc_index);

    ProglangType ptype = base.type.elementType();
    ProglangType rtype = base.rep_type.elementType();
    VarComparability comp = base.comparability.elementType();
    return new VarInfo(name, ptype, rtype, comp);
  }

}
