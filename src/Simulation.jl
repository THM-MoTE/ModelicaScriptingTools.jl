# This module contains basic utility functions and utility functions to
# simulate modelica models using OMJulia

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
    loadModel(omc:: OMCSession, name:: String; check=true, instantiate=true)

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
    errors in the model structure (e.g. since Modelica 1.16, unit consistency
    checks are performed here).

If `ismodel`, `check`, or `instantiate` are false, the loading process is
stopped at the respective steps.
""" # TODO: which errors are found by instantiateModel that checkModel does not find?
function loadModel(omc:: OMCSession, name:: String; ismodel=true, check=true, instantiate=true)
    success = sendExpression(omc, "loadModel($name)")
    es = getErrorString(omc)
    if isnothing(success)
        # i have seen this happen, but do not know why it does occur
        throw(MoSTError("Unexpected error: loadModel($name) returned nothing", es))
    end
    if !success || length(es) > 0
        throw(MoSTError("Could not load $name", es))
    end
    if !ismodel
        return
    end
    success = sendExpression(omc, "isModel($name)")
    if !success
        throw(MoSTError("Model $name not found in MODELICAPATH", ""))
    end
    if !check
        return
    end
    check = sendExpression(omc, "checkModel($name)")
    es = getErrorString(omc)
    if !startswith(check, "Check of $name completed successfully")
        throw(MoSTError("Model check of $name failed", join([check, es], "\n")))
    end
    if !instantiate
        return
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

In `override`, an additional key `"interval"` is allowed to recalculate the
`"numberOfIntervals"` based on the step size given as value to this key.

Throws a [`MoSTError`](@ref) if the model `name` was not loaded beforehand using
[`loadModel(omc:: OMCSession, name:: String)`](@ref).
"""
function getSimulationSettings(omc:: OMCSession, name:: String; override=Dict())
    values = sendExpression(omc, "getSimulationOptions($name)")
    settings = Dict(
        "startTime"=>values[1], "stopTime"=>values[2],
        "tolerance"=>values[3], "numberOfIntervals"=>values[4],
        "outputFormat"=>"csv", "variableFilter"=>".*"
    )
    interval = values[5]
    settings["variableFilter"] = getVariableFilter(omc, name)
    for x in keys(settings)
        if x in keys(override)
            settings[x] = override[x]
        end
    end
    # the overriding of simulation time or interval size may require additional
    # changes to the numberOfIntervals setting
    hasinterval = haskey(override, "interval")
    onlytime = (haskey(override, "startTime") || haskey(override, "stopTime")
        && !haskey(override, "interval")
        && !haskey(override, "numberOfIntervals")
    )
    if hasinterval || onlytime
        timespan = settings["stopTime"] - settings["startTime"]
        interval = get(override, "interval", interval)
        settings["numberOfIntervals"]  = trunc(Int, timespan / interval)
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
    getVersion(omc:: OMCSession)

Returns the version of the OMCompiler as a triple (major, minor, patch).
"""
function getVersion(omc:: OMCSession)
    versionstring = sendExpression(omc, "getVersion()")
    # example: OMCompiler v1.17.0-dev.94+g4da66238ab
    vmatch = match(r"^OMCompiler v(\d+)\.(\d+).(\d+)", versionstring)
    if isnothing(vmatch)
        throw(MoSTError(omc, "Got unexpected version string: $versionstring"))
    end
    cap = map(x -> parse(Int, x), vmatch.captures)
    major, minor, patch = cap
    return Tuple([major, minor, patch])
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
    prepare(s:: String) = "\"$(moescape(s))\""
    prepare(x:: Number) = x
    setstring = join(("$k=$(prepare(v))" for (k,v) in settings), ", ")
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
    setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)

Creates an `OMCSession` and prepares it by preforming the following steps:

* create the directory `outdir` if it does not already exist
* change the working directory of the OMC to `outdir`
* add `modeldir` to the MODELICAPATH
* enable unit checking with the OMC command line option
    `--unitChecking` (unless `checkunits` is false)
* load the modelica standard library (`loadModel(Modelica)`)

If `quiet` is false, the resulting MODELICAPATH is printed to stdout.

Returns the newly created OMCSession.
"""
function setupOMCSession(outdir, modeldir; quiet=false, checkunits=true, sleeptime=0.5)
    # create output directory
    if !isdir(outdir)
        mkpath(outdir)
    end
    # create sessions
    omc = OMCSession()
    # sleep for a short while, because otherwise first ZMQ call may freeze
    sleep(sleeptime)
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
        flag = if getVersion(omc) >= Tuple([1, 16, 0])
            "--unitChecking"
        else
            "--preOptModules+=unitChecking"
        end
        sendExpression(omc, "setCommandLineOptions(\"$flag\")")
    end
    if !quiet
        opts = sendExpression(omc, "getCommandLineOptions()")
        println("Using command line options: $opts")
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

If you want to use a MoST.jl script for continuous integration, you can use
the following shell command to add a timeout to your script and treat the
timeout as a successful test run (which is, of course, unsafe).

```bash
(timeout 2m julia myTestScript.jl; rc=\$?; if [ \${rc} -eq 124 ]; then exit 0; else exit \${rc}; fi;)
```
"""
function closeOMCSession(omc:: OMCSession; quiet=false)
    if !quiet
        println("Closing OMC session")
    end
    # only send, do not wait for response since this may lead to freeze
    # TODO: test whether this really solves the freezing issues
    send(omc.socket, "quit()")
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
