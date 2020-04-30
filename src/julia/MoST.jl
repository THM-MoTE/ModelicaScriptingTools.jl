module MoST
    using Base.Filesystem
    using Test
    using OMJulia # note: needs 0.1.1 (unreleased) -> install from Github


    struct MoSTError <: Exception
        msg:: String
        omc:: String
    end

    Base.showerror(io::IO, e::MoSTError) = print(io, msg, "OMC error string:\n", omc)

    MoSTError(omc:: OMJulia.OMCSession, msg:: String) = MoSTError(msg, OMJulia.sendExpression(omc, "getErrorString()"))

    function loadModel(omc:: OMJulia.OMCSession, name:: String)
        success = OMJulia.sendExpression(omc, "loadModel($name)")
        es = OMJulia.sendExpression(omc, "getErrorString()")
        if !success || length(es) > 0
            throw(MoSTError("Could not load $name", es))
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
        csann = OMJulia.sendExpression(omc, "getAnnotationNamedModifiers($name, \"__ChrisS_testing\")")
        varfilter = ".*"
        if "testedVariableFilter" in csann
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
        es = OMJulia.sendExpression(omc, "getErrorString()")
        if length(es) > 0
            throw(MoSTError("Simulation of $name failed", es))
        end
    end

    function regressionTest(omc:: OMJulia.OMCSession, name:: String, refdir:: String)
        actname = "$(name)_res.csv"
        refname = joinpath(refdir, actname)
        actvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"$actname\")")
        refvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"$refname\")")
        missingRef = setdiff(Set(actvars), Set(refvars))
        @test isempty(missingRef)
        # if variable sets differ, we should only check the variables that are present in both files
        vars = collect(intersect(Set(actvars), Set(refvars)))
        varsStr = join(map(x -> "\"$x\"", vars), ", ")
        cmd = "diffSimulationResults(\"$outname\", \"$refname\", \"$(name)_diff.log\", vars={ $varsStr })"
        eq, ineqAr = OMJulia.sendExpression(omc, cmd)
        @test isempty(ineqAr)
    end

    function testmodel(omc, name; override=Dict(), refdir="../regRefData")
        @test loadModel(omc, name)
        @test simulate(omc, name, getSimulationSettings(omc, name; override=override))

        # compare simulation results to regression data
        if isfile("$(joinpath(refdir, name))_res.csv")
            regressionTest(omc, name, refdir)
        else
            write(Base.stderr, "WARNING: no reference data for regression test of $name\n")
        end
    end

    function setupOMCSession(outdir, modeldir; quiet=false)
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
end
