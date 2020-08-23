model FunctionNames
  Real x(start=0, fixed=true);
  model Submodel
    Real a;
    Real b;
    function g
      input Real x;
      output Real y;
    algorithm
      y := x + 1;
    end g;
  equation
    b = a + g(a);
  end Submodel;
  Submodel sm;
  function f
    input Real x;
    output Real y;
  algorithm
    y := 2 * x;
  end f;
equation
  sm.a = x;
  der(x) = 1/f(sm.b);
end FunctionNames;
