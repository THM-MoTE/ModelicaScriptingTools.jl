module ModelicaScriptingTools

using Base.Filesystem: isfile
using Test: @test
using CSV: CSV
using OMJulia: OMCSession, sendExpression, Parser
using ZMQ: send, recv # only needed for sendExpressionRaw which is a workaround for OMJulia bugs
using DataFrames: DataFrame

export moescape, mounescape, MoSTError, loadModel, getSimulationSettings,
    getVariableFilter, simulate, regressionTest, testmodel,
    setupOMCSession, closeOMCSession, withOMC

"""
    MoSTError

Error class for OMJulia-related errors that contains the OMC error message.
"""
struct MoSTError <: Exception
    msg:: String
    omc:: String
end

Base.showerror(io::IO, e::MoSTError) = print(io, e.msg, "\n---\nOMC error string:\n", e.omc)

"""
    MoSTError(omc:: OMCSession, msg:: String)

Creates MoSTError with message `msg` and current result of `getErrorString()`
as OMC error message.
"""
MoSTError(omc:: OMCSession, msg:: String) = MoSTError(msg, getErrorString(omc))

"""
    loadModel(omc:: OMCSession, name:: String)

Loads the model with fully qualified name `name` from a source file available
from the model directory.
Note that this refers to the model *name*, not the model *file*.

Example:

    loadModel(omc, "Modelica.SIunits.Voltage")

This function will actually call several OM scripting functions to
ensure that as many errors in the model are caught and thrown as
[`MoSTError`](@ref)s as possible:

* First, `loadModel(name)` is called to load the model if it exists. This
    call does only fail if the toplevel model does not exist. E.g.,
    `loadModel(Modelica.FooBar)` would still return true, because `Modelica`
    could be loaded, although `FooBar` does not exist.
* We then check with `isModel(name)` if the model actually exists.
* With `checkModel(name)` we find errors such as missing or mistyped variables.
* Finally, we use `instantiateModel(name)` which can sometimes find additional
    errors in the model structure.
""" # TODO: which errors are found by instantiateModel that checkModel does not find?
function loadModel(omc:: OMCSession, name:: String)
    success = sendExpression(omc, "loadModel($name)")
    es = getErrorString(omc)
    if !success || length(es) > 0
        throw(MoSTError("Could not load $name", es))
    end
    success = sendExpression(omc, "isModel($name)")
    if !success
        throw(MoSTError("Model $name not found in MODELICAPATH", ""))
    end
    check = sendExpression(omc, "checkModel($name)")
    es = getErrorString(omc)
    if !startswith(check, "Check of $name completed successfully")
        throw(MoSTError("Model check of $name failed", join([check, es], "\n")))
    end
    inst = sendExpression(omc, "instantiateModel($name)")
    es = getErrorString(omc)
    if length(es) > 0
        throw(MoSTError("Model $name could not be instantiated", es))
    end
end

"""
    moescape(s:: String)

Escapes string according to Modelica specification for string literals.

Escaped characters are: `['\\\\', '"', '?', '\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v',]`
"""
function moescape(s:: String)
    rep = Dict(
        '\\' => "\\\\",
        '"' => "\\\"",
        '?' => "\\?",
        '\a' => "\\a",
        '\b' => "\\b",
        '\f' => "\\f",
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
        '\v' => "\\v",
    )
    return join([(x in keys(rep) ? rep[x] : x) for x in s])
end

"""
    moescape(s:: String)
    moescape(io:: IO, s:: String)

Unescapes string that was escaped by [`moescape(s:: String)`](@ref) or that
was returned from the OMC compiler. If `io` is given the string is printed to
the `IO` object, otherwise it is returned directly.
"""
function mounescape(io:: IO, s:: String)
    rev = Dict(
        "\\\\" => '\\',
        "\\\"" => '"',
        "\\?" => '?',
        "\\a" => '\a',
        "\\b" => '\b',
        "\\f" => '\f',
        "\\n" => '\n',
        "\\r" => '\r',
        "\\t" => '\t',
        "\\v" => '\v'
    )
    i = Iterators.Stateful(s)
    while !isempty(i)
        c = popfirst!(i)
        if c != '\\' || isempty(i)
            print(io, c)
        else
            nxt = popfirst!(i)
            print(io, rev[join([c, nxt])])
        end
    end
end
mounescape(s::String) = sprint(mounescape, s; sizehint=lastindex(s))

function getErrorString(omc:: OMCSession)
    es = sendExpressionRaw(omc, "getErrorString()")
    return strip(strip(mounescape(es)),'"')
end

function sendExpressionRaw(omc:: OMCSession, expr)
    # FIXME this function should be replaced by sendExpression(omc, parsed=false)
    send(omc.socket, expr)
    message=recv(omc.socket)
    return unsafe_string(message)
end

"""
    getSimulationSettings(omc:: OMCSession, name:: String; override=Dict())

Reads simulation settings from the model `name`.
Any content in `override` will override the setting with the respective key.

Returns a Dict with the keys `"startTime"`, `"stopTime"`, `"tolerance"`,
`"numberOfIntervals"`, `"outputFormat"` and `"variableFilter"`.
If any of these settings are not defined in the model file, they will be
filled with default values.

Throws a [`MoSTError`](@ref) if the model `name` was not loaded beforehand using
[`loadModel(omc:: OMCSession, name:: String)`](@ref).
"""
function getSimulationSettings(omc:: OMCSession, name:: String; override=Dict())
    values = sendExpression(omc, "getSimulationOptions($name)")
    settings = Dict(
        "startTime"=>values[1], "stopTime"=>values[2],
        "tolerance"=>values[3], "numberOfIntervals"=>values[4],
        "outputFormat"=>"\"csv\"", "variableFilter"=>"\".*\""
    )
    settings["variableFilter"] = "\"$(moescape(getVariableFilter(omc, name)))\""
    for x in keys(settings)
        if x in keys(override)
            settings[x] = override[x]
        end
    end
    return settings
end

"""
    getVariableFilter(omc:: OMCSession, name:: String)

Reads the value for the `variableFilter` simulation setting from the model
file if it has been defined.
MoST assumes that this value will be given in a vendor-specific annotation
of the form `__MoST_experiment(variableFilter=".*")`.
If such an annotation is not found, the default filter `".*"` is returned.

Throws a [`MoSTError`](@ref) if the model `name` does not exist.
"""
function getVariableFilter(omc:: OMCSession, name:: String)
    mostann = sendExpression(omc, "getAnnotationNamedModifiers($name, \"__MoST_experiment\")")
    if isnothing(mostann)
        throw(MoSTError("Model $name not found", ""))
    end
    varfilter = ".*"
    if "variableFilter" in mostann
        varfilter = sendExpression(omc, "getAnnotationModifierValue($name, \"__MoST_experiment\", \"variableFilter\")")
    end
    return varfilter
end

"""
    simulate(omc:: OMCSession, name::String)
    simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})

Simulates the model `name` which must have been loaded before with
[`loadModel(omc:: OMCSession, name:: String)`](@ref).
The keyword-parameters in `settings` are directly passed to the OpenModelica
scripting function `simulate()`.
If the parameter is not given, it is obtained using
[`getSimulationSettings(omc:: OMCSession, name:: String; override=Dict())`](@ref).

The simulation output will be written to the current working directory of the
OMC that has been set by
[`setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)`](@ref).

The simulation result is checked for errors with the following methods:

* The messages returned by the OM scripting call are checked for
    the string `Simulation execution failed`. This will, e.g., be the case
    if there is an arithmetic error during simulation.
* The abovementioned messages are checked for the string `| warning |` which
    hints at missing initial values and other non-critical errors.
* The error string returned by the OM scripting function `getErrorString()`
    should be empty if the simulation was successful.

If any of the abovementioned methods reveals errors, a [`MoSTError`](@ref)
is thrown.
""" # TODO which class of errors can be found using the error string?
function simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})
    setstring = join(("$k=$v" for (k,v) in settings), ", ")
    r = sendExpression(omc, "simulate($name, $setstring)")
    if startswith(r["messages"], "Simulation execution failed")
        throw(MoSTError("Simulation of $name failed", r["messages"]))
    end
    if occursin("| warning |", r["messages"])
        throw(MoSTError("Simulation of $name produced warning", r["messages"]))
    end
    es = getErrorString(omc)
    if length(es) > 0
        throw(MoSTError("Simulation of $name failed", es))
    end
end
simulate(omc:: OMCSession, name::String) = simulate(omc, name, getSimulationSettings(omc, name))

"""
    regressionTest(
        omc:: OMCSession, name:: String, refdir:: String;
        relTol:: Real = 1e-6, variableFilter:: String = "", outputFormat="csv"
    )

Performs a regression test that ensures that variable values in the simulation
output are approximately equal to variables in the reference file in the
directory given by `refdir`.
Note that `refdir` must be relative to the current working directory of the OMC
(i.e. the output directory), not the current working directory of Julia.
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
    refname = joinpath(refdir, actname)
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
    testmodel(omc, name; override=Dict(), refdir="../regRefData", regRelTol:: Real= 1e-6)

Performs a full test of the model named `name` with the following steps:

* Load the model using [`loadModel(omc:: OMCSession, name:: String)`](@ref) (called inside `@test`)
* Simulate the model using [`simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})`](@ref) (called inside `@test`)
* If a reference file exists in `refdir`, perform a regression test with
    [`regressionTest(omc:: OMCSession, name:: String, refdir:: String; relTol:: Real = 1e-6, variableFilter:: String = "", outputFormat="csv")`](@ref).
"""
function testmodel(omc, name; override=Dict(), refdir="../regRefData", regRelTol:: Real= 1e-6)
    if "outputFormat" in keys(override)
        outputFormat = override["outputFormat"]
    else
        outputFormat = "csv"
    end
    @test isnothing(loadModel(omc, name))
    settings = getSimulationSettings(omc, name; override=override)
    varfilter = mounescape(settings["variableFilter"][2:end-1])
    @test isnothing(simulate(omc, name, settings))

    # compare simulation results to regression data
    wd = sendExpression(omc, "cd()")
    if isfile("$(joinpath(wd, refdir, name))_res.$outputFormat")
        regressionTest(omc, name, refdir; relTol=regRelTol, variableFilter=varfilter, outputFormat=outputFormat)
    else
        write(Base.stderr, "WARNING: no reference data for regression test of $name\n")
    end
end

"""
    setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)

Creates an `OMCSession` and prepares it by preforming the following steps:

* add `modeldir` to the MODELICAPATH
* enable unit checking with the OMC command line option
    `--preOptModules+=unitChecking` (unless `checkunits` is false)
* load the modelica standard library (`loadModel(Modelica)`)

If `quiet` is false, the resulting MODELICAPATH is printed to stdout.

Returns the newly created OMCSession.
"""
function setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)
    # create sessions
    omc = OMCSession()
    # move to output directory
    sendExpression(omc, "cd(\"$(moescape(outdir))\")")
    # set modelica path
    mopath = sendExpression(omc, "getModelicaPath()")
    mopath = "$mopath:$(moescape(abspath(modeldir)))"
    if !quiet
        println("Setting MODELICAPATH to ", mopath)
    end
    sendExpression(omc, "setModelicaPath(\"$mopath\")")
    # enable unit checking
    if checkunits
        sendExpression(omc, "setCommandLineOptions(\"--preOptModules+=unitChecking\")")
    end
    # load Modelica standard library
    sendExpression(omc, "loadModel(Modelica)")
    return omc
end

"""
    closeOMCSession(omc:: OMCSession; quiet=false)

Closes the OMCSession given by `omc`, shutting down the OMC instance.

Due to a [bug in the current release version of OMJulia](https://github.com/OpenModelica/jl/issues/32)
the function may occasionally freeze.
If this happens, you have to stop the execution with CTRL-C.
You can tell that this is the case if the output `Closing OMC session` is
printed to stdout, but it is not followed by `Done`.
If desired, these outputs can be disabled by setting `quiet=true`.
"""
function closeOMCSession(omc:: OMCSession; quiet=false)
    if !quiet
        println("Closing OMC session")
    end
    sleep(1) # somewhat alleviates issue #32 (freeze on quit())
    try
        # parsed=false is currently unreleased solution to issue #22
        # that only works when OMJulia is installed directly from github
        sendExpression(omc, "quit()", parsed=false)
    catch e
        if !isa(e, MethodError) # only catch MethodErrors
            rethrow()
        end
        # meathod error means we have version 0.1.0
        # => perform workaround for issue #22 in version 0.1.0 of OMJulia
        # https://github.com/OpenModelica/jl/issues/22
        try
            sendExpression(omc, "quit()")
        catch e
            # ParseError is expected
            if !isa(e, Parser.ParseError)
                rethrow()
            end
        end
    end
    if !quiet
        println("Done")
    end
end

"""
    withOMC(f:: Function, outdir, modeldir; quiet=false, checkunits=true)

Allows to use OMCSession with do-block syntax, automatically closing the
session after the block has been executed.
For the parameter definition see [`setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)`](@ref).

Example:

```julia
withOMC("test/out", "test/res") do omc
    loadModel(omc, "Example")
end
```
"""
function withOMC(f:: Function, outdir, modeldir; quiet=false, checkunits=true)
    omc = setupOMCSession(outdir, modeldir; quiet=quiet, checkunits=checkunits)
    try
        f(omc)
    finally
        closeOMCSession(omc)
    end
end

end
