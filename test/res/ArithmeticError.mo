model ArithmeticError
  Real r(start=1, fixed=true);
  Real x = if time < 1 then 7 else 0;
equation
  der(r) = 1/x;
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(variableFilter="r")
);
end ArithmeticError;
