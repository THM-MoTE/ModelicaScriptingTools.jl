# This file contains all utility functions that can be used for testing
# Modelica models with the built-in unit testing support of Julia

"""
    regressionTest(
        omc:: OMCSession, name:: String, refdir:: String;
        relTol:: Real = 1e-6, variableFilter:: String = "", outputFormat="csv"
    )

Performs a regression test that ensures that variable values in the simulation
output are approximately equal to variables in the reference file in the
directory given by `refdir`.
Both the simulation output and the reference file must have the standard name
`"\$(name)_res.\$outputFormat"`.
This function also assumes that the simulation a simulation of the model named
`name` has already been run with
[`simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})`](@ref).

The test consists of the following checks performed with `@test`:

* Are there no variables in the simulation output that have no corresponding
    variable in the reference file? For this check, variables are ignored that
    occur in the simulation file but should not have been selected by the
    regex `variableFilter`. This can happen in OpenModelica, because sometimes
    alias variables are added to the output even though they do not match the
    `variableFilter`.
* Are there no variables in the reference file that have no corresponding
    variable in the simulation output?
* Is the intersection of common variables in both files nonempty?
* Is the length of the simulation output equal to the length of the reference
    file?
* Are there any variables in the simulation file that do not satisfy
    `isapprox(act, ref, rtol=relTol)` for all values?

NOTE: There is a OM scripting function `compareSimulationResults()` that could
be used for this task, but it is not documented and does not react to changes
of its `relTol` parameter in a predictable way.
"""
function regressionTest(omc:: OMCSession, name:: String, refdir:: String; relTol:: Real = 1e-6, variableFilter:: String = "", outputFormat="csv")
    actname = "$(name)_res.$outputFormat"
    # make refdir relative to CWD of OMC
    omcrefdir = relpath(refdir, sendExpression(omc, "cd()"))
    refname = joinpath(omcrefdir, actname)
    actvars = sendExpression(omc, "readSimulationResultVars(\"$actname\")")
    refvars = sendExpression(omc, "readSimulationResultVars(\"$refname\")")
    missingRef = setdiff(Set(actvars), Set(refvars))
    # ignore variables without reference if they should not have been selected in the first place
    if length(variableFilter) > 0
        varEx = Regex("^($(variableFilter))\$")
        missingRef = filter(x -> occursin(varEx,x), missingRef)
    end
    @test isempty(missingRef)
    missingAct = setdiff(Set(refvars), Set(actvars))
    @test isempty(missingAct)
    # if variable sets differ, we should only check the variables that are present in both files
    vars = collect(intersect(Set(actvars), Set(refvars)))
    @test !isempty(vars)

    wd = sendExpression(omc, "cd()")
    actpath = joinpath(wd, actname)
    refpath = joinpath(wd, refname)
    function readSimulationResultMat(fn:: String)
        # TODO can be replaced by DataFrame(MAT.matread(actpath)) once
        # https://github.com/JuliaIO/MAT.jl/pull/132 is merged
        fnrel = relpath(fn, sendExpression(omc, "cd()"))
        data = sendExpression(omc, "readSimulationResult(\"$fnrel\", {$(join(vars, ", "))})")
        df = DataFrame(Dict(zip(vars, data)))
        return df
    end
    if outputFormat == "csv"
        actdata = DataFrame(CSV.File(actpath))
        refdata = DataFrame(CSV.File(refpath))
    elseif outputFormat == "mat"
        actdata = readSimulationResultMat(actpath)
        refdata = readSimulationResultMat(refpath)
    else
        throw(MoSTError("unknown output format $outputFormat", ""))
    end
    # check if length is equal
    @test size(actdata, 1) == size(refdata, 1)
    n = min(size(actdata, 1), size(refdata, 1))
    # find unequal variables
    unequalVars = filter(x -> !isapprox(actdata[1:n,Symbol(x)], refdata[1:n,Symbol(x)]; rtol=relTol), vars)
    @test isempty(unequalVars)
end

"""
    testmodel(omc, name; override=Dict(), refdir="regRefData", regRelTol:: Real= 1e-6)

Performs a full test of the model named `name` with the following steps:

* Load the model using [`loadModel(omc:: OMCSession, name:: String)`](@ref) (called inside `@test`)
* Simulate the model using [`simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})`](@ref) (called inside `@test`)
* If a reference file exists in `refdir`, perform a regression test with
    [`regressionTest(omc:: OMCSession, name:: String, refdir:: String; relTol:: Real = 1e-6, variableFilter:: String = "", outputFormat="csv")`](@ref).
"""
function testmodel(omc, name; override=Dict(), refdir="regRefData", regRelTol:: Real= 1e-6)
    @test isnothing(loadModel(omc, name))
    settings = getSimulationSettings(omc, name; override=override)
    outputFormat = settings["outputFormat"]
    varfilter = settings["variableFilter"]
    @test isnothing(simulate(omc, name, settings))

    # compare simulation results to regression data
    if isfile("$(joinpath(refdir, name))_res.$outputFormat")
        regressionTest(omc, name, refdir; relTol=regRelTol, variableFilter=varfilter, outputFormat=outputFormat)
    else
        write(Base.stderr, "WARNING: no reference data for regression test of $name\n")
    end
end
