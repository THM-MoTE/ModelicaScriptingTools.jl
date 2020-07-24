model MissingInitialValue
  Modelica.SIunits.Voltage r;
equation
  der(r) = 1;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(testedVariableFilter="sub\\.alias")
);
end MissingInitialValue;
