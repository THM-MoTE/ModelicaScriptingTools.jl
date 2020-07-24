model TwoVarExample
  Modelica.SIunits.Voltage v(start=0, fixed=true);
  Modelica.SIunits.Current i(start=1, fixed=true);
equation
  der(v) = 1;
  der(i) = 2;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(testedVariableFilter="i|v")
);
end TwoVarExample;
