module ModelicaScriptingTools

using Base.Filesystem
using Test
using CSV
using OMJulia # note: needs 0.1.1 (unreleased) -> install from Github
using ZMQ # only needed for sendExpressionRaw which is a workaround for OMJulia bugs

struct MoSTError <: Exception
    msg:: String
    omc:: String
end

Base.showerror(io::IO, e::MoSTError) = print(io, e.msg, "\n---\nOMC error string:\n", e.omc)

MoSTError(omc:: OMJulia.OMCSession, msg:: String) = MoSTError(msg, getErrorString(omc))

function loadModel(omc:: OMJulia.OMCSession, name:: String)
    success = OMJulia.sendExpression(omc, "loadModel($name)")
    es = getErrorString(omc)
    if !success || length(es) > 0
        throw(MoSTError("Could not load $name", es))
    end
    success = OMJulia.sendExpression(omc, "isModel($name)")
    if !success
        throw(MoSTError("Model $name not found in MODELICAPATH", ""))
    end
    check = OMJulia.sendExpression(omc, "checkModel($name)")
    es = getErrorString(omc)
    if !startswith(check, "Check of $name completed successfully")
        throw(MoSTError("Model check of $name failed", join([check, es], "\n")))
    end
    inst = OMJulia.sendExpression(omc, "instantiateModel($name)")
    es = getErrorString(omc)
    if length(es) > 0
        throw(MoSTError("Model $name could not be instantiated", es))
    end
end

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

function getErrorString(omc:: OMJulia.OMCSession)
    es = sendExpressionRaw(omc, "getErrorString()")
    return strip(strip(mounescape(es)),'"')
end

function sendExpressionRaw(omc:: OMJulia.OMCSession, expr)
    # FIXME this function should be replaced by sendExpression(omc, parsed=false)
    ZMQ.send(omc.socket, expr)
    message=ZMQ.recv(omc.socket)
    return unsafe_string(message)
end

function getSimulationSettings(omc:: OMJulia.OMCSession, name:: String; override=Dict())
    values = OMJulia.sendExpression(omc, "getSimulationOptions($name)")
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

function getVariableFilter(omc:: OMJulia.OMCSession, name:: String)
    mostann = OMJulia.sendExpression(omc, "getAnnotationNamedModifiers($name, \"__MoST_experiment\")")
    if isnothing(mostann)
        throw(MoSTError("Model $name not found", ""))
    end
    varfilter = ".*"
    if "testedVariableFilter" in mostann
        varfilter = OMJulia.sendExpression(omc, "getAnnotationModifierValue($name, \"__ChrisS_testing\", \"testedVariableFilter\")")
    end
    return varfilter
end

function simulate(omc:: OMJulia.OMCSession, name::String, settings:: Dict{String, Any})
    setstring = join(("$k=$v" for (k,v) in settings), ", ")
    r = OMJulia.sendExpression(omc, "simulate($name, $setstring)")
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

function regressionTest(omc:: OMJulia.OMCSession, name:: String, refdir:: String; relTol:: Real = 1e-6, variableFilter:: String = "")
    actname = "$(name)_res.csv"
    refname = joinpath(refdir, actname)
    actvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"$actname\")")
    refvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"$refname\")")
    missingRef = setdiff(Set(actvars), Set(refvars))
    # ignore variables without reference if they should not have been selected in the first place
    if length(variableFilter) > 0
        # NOTE: OpenModelica only adds ^ and $, but not the group
        # we still add the group because it is the correct way to make a
        # regex exact
        varEx = Regex("^($(variableFilter))\$")
        missingRef = filter(x -> occursin(varEx,x), missingRef)
    end
    @test isempty(missingRef)
    missingAct = setdiff(Set(refvars), Set(actvars))
    @test isempty(missingAct)
    # if variable sets differ, we should only check the variables that are present in both files
    vars = collect(intersect(Set(actvars), Set(refvars)))
    @test !isempty(vars)

    wd = OMJulia.sendExpression(omc, "cd()")
    actdata = CSV.read(joinpath(wd, actname))
    refdata = CSV.read(joinpath(wd, refname))
    # check if length is equal
    @test size(actdata, 1) == size(refdata, 1)
    n = min(size(actdata, 1), size(refdata, 1))
    # find unequal variables
    unequalVars = filter(x -> !isapprox(actdata[1:n,Symbol(x)], refdata[1:n,Symbol(x)]; rtol=relTol), vars)
    @test isempty(unequalVars)
end

function testmodel(omc, name; override=Dict(), refdir="../regRefData", regRelTol:: Real= 1e-6)
    @test isnothing(loadModel(omc, name))
    settings = getSimulationSettings(omc, name; override=override)
    varfilter = mounescape(settings["variableFilter"][2:end-1])
    @test isnothing(simulate(omc, name, settings))

    # compare simulation results to regression data
    wd = OMJulia.sendExpression(omc, "cd()")
    if isfile("$(joinpath(wd, refdir, name))_res.csv")
        regressionTest(omc, name, refdir; relTol=regRelTol, variableFilter=varfilter)
    else
        write(Base.stderr, "WARNING: no reference data for regression test of $name\n")
    end
end

function setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)
    # create sessions
    omc = OMJulia.OMCSession()
    # move to output directory
    OMJulia.sendExpression(omc, "cd(\"$(moescape(outdir))\")")
    # set modelica path
    mopath = OMJulia.sendExpression(omc, "getModelicaPath()")
    mopath = "$mopath:$(moescape(abspath(modeldir)))"
    if !quiet
        println("Setting MODELICAPATH to ", mopath)
    end
    OMJulia.sendExpression(omc, "setModelicaPath(\"$mopath\")")
    # enable unit checking
    if checkunits
        OMJulia.sendExpression(omc, "setCommandLineOptions(\"--preOptModules+=unitChecking\")")
    end
    # load Modelica standard library
    OMJulia.sendExpression(omc, "loadModel(Modelica)")
    return omc
end

function closeOMCSession(omc:: OMJulia.OMCSession; quiet=false)
    if !quiet
        println("Closing OMC session")
    end
    sleep(1) # somewhat alleviates issue #32 (freeze on quit())
    try
        # parsed=false is currently unreleased solution to issue #22
        # that only works when OMJulia is installed directly from github
        OMJulia.sendExpression(omc, "quit()", parsed=false)
    catch e
        if !isa(e, MethodError) # only catch MethodErrors
            rethrow()
        end
        # meathod error means we have version 0.1.0
        # => perform workaround for issue #22 in version 0.1.0 of OMJulia
        # https://github.com/OpenModelica/OMJulia.jl/issues/22
        try
            OMJulia.sendExpression(omc, "quit()")
        catch e
            # ParseError is expected
            if !isa(e, OMJulia.Parser.ParseError)
                rethrow()
            end
        end
    end
    if !quiet
        println("Done")
    end
end

function withOMC(f:: Function, outdir, modeldir; quiet=false, checkunits=true)
    omc = setupOMCSession(outdir, modeldir; quiet=quiet, checkunits=checkunits)
    try
        f(omc)
    finally
        closeOMCSession(omc)
    end
end

end
