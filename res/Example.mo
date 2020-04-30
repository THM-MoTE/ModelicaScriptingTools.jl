model Example
  Real r(start=0, fixed=true);
equation
  der(r) = 1;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __ChrisS_testing(testedVariableFilter="r")
);
end Example;
