#!/bin/bash
# This script provides a way to ensure that the tests in failingRegTests.jl
# fail in the expected way when it is called from the CI script.
# It must be run from the main project folder as test/testFailing.sh
RES=$(julia --project=. test/failingRegTests.jl | egrep -o 'isempty\(missingAct\)|isempty\(missingRef\)|isempty\(unequalVars\)' | tr '\n' '#')
REF="isempty(missingAct)#isempty(missingRef)#isempty(unequalVars)#"
if [ "$RES" == "$REF" ]; then
  echo "pass"
  exit 0
else
  echo "fail"
  echo $RES
  echo "is not equal to"
  echo $REF
  exit 1
fi
