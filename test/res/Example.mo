model Example
  Modelica.SIunits.Voltage r(start=0, fixed=true);
  model ExSub
    Modelica.SIunits.Voltage alias;
  end ExSub;
  ExSub sub(alias=r);
equation
  der(r) = 1;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(variableFilter="sub\\.alias")
);
end Example;
