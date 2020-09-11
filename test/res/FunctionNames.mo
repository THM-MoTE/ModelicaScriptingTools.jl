model FunctionNames
  Real x(start=0, fixed=true);
  model Submodel
    Real a;
    Real b;
    replaceable function h = f;
    function g
      input Real x;
      output Real y;
    algorithm
      y := x + 1;
    end g;
  equation
    b = h(a) + g(a);
  end Submodel;
  Submodel sm(redeclare function h = f(x2=1));
  function f
    input Real x1;
    input Real x2 = 0;
    output Real y;
  algorithm
    y := 2 * x1 + x2;
  end f;
equation
  sm.a = x;
  der(x) = 1/f(sm.b);
end FunctionNames;
