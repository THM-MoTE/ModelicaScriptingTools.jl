model Example
  Real r(start=0, fixed=true);
  model ExSub
    Real alias;
  end ExSub;
  ExSub sub(alias=r);
equation
  der(r) = 1;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __ChrisS_testing(testedVariableFilter="sub\\.r")
);
end Example;
