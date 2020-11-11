model FunctionNames
  Real x(start=0, fixed=true);
  model Submodel
    Real a;
    Real b;
    function innerF
      input Real x;
      input Real a = 1;
      output Real y;
    algorithm
      y := x + a;
    end innerF;
    replaceable function f = g;
    function g
      input Real x;
      output Real y;
    algorithm
      y := x + 1;
    end g;
  equation
    b = f(a) + g(a);
  end Submodel;
  Submodel sm(redeclare function f = f(x2=1));
  function f2 = f(redeclare function inf = Submodel.innerF(a = 1));
  function f
    input Real x1;
    input Real x2 = 0;
    replaceable function inf = Submodel.innerF;
    output Real y;
  algorithm
    y := 2 * x1 + inf(x2);
  end f;
equation
  sm.a = x;
  der(x) = 1/f(sm.b) + f2(sm.b);
end FunctionNames;
