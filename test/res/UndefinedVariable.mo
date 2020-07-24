model UndefinedVariable
equation
  der(r) = 1; // variable r was never defined
annotation(
  experiment(StartTime = 0, StopTime = 5, Tolerance = 1e-6, Interval = 1e-1),
  __MoST_experiment(testedVariableFilter="sub\\.alias")
);
end UndefinedVariable;
