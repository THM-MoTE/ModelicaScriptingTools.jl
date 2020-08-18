model DocExample
  Modelica.SIunits.Voltage r(start=0, fixed=true) "some potential";
  model ExSub
    Modelica.SIunits.Voltage alias;
  end ExSub;
  ExSub sub(alias=r);
  Real foo "second sample variable";
  function f
    input Real x;
    input Real y;
    output Real res;
  algorithm
    res := x ^ y + y;
  end f;
equation
  der(r) = 1 / foo;
  foo = f(r, 2);
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(variableFilter="sub\\.alias"),
  Documentation(info="
      <html>
        <p>This is an example documentation for the DocExample class.</p>
      </html>
    ")
);
end DocExample;
