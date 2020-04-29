using Base.Filesystem
using Test

# move to parent directory of this file
moroot = dirname(@__DIR__)
cd(moroot)

# ugly workaround for using latest OMJulia with libgit2-julia incompatibility
using Pkg
Pkg.activate("3rdparty/OMJulia.jl")
Pkg.instantiate()
# end of ugly workaround
using OMJulia

# create outdir and move working directory there to capture OMC outputs
outdir = "out"
if !ispath(outdir)
    mkdir(outdir)
end
cd(outdir)

function testmodel(omc, name; override=Dict())
    r = OMJulia.sendExpression(omc, "loadModel($name)")
    @test r
    es = OMJulia.sendExpression(omc, "getErrorString()")
    @test es == ""
    values = OMJulia.sendExpression(omc, "getSimulationOptions($name)")
    settings = Dict(
        "startTime"=>values[1], "stopTime"=>values[2],
        "tolerance"=>values[3], "numberOfIntervals"=>values[4],
        "outputFormat"=>"\"csv\"", "variableFilter"=>"\".*\""
    )
    for x in keys(settings)
        if x in keys(override)
            settings[x] = override[x]
        end
    end
    # extract variable filter if present as vendor-specific annotation
    csann = OMJulia.sendExpression(omc, "getAnnotationNamedModifiers($name, \"__ChrisS_testing\")")
    varfilter = ".*"
    if "testedVariableFilter" in csann
        varfilter = OMJulia.sendExpression(omc, "getAnnotationModifierValue($name, \"__ChrisS_testing\", \"testedVariableFilter\")")
        settings["variableFilter"] = "\"$varfilter\""
    end
    setstring = join(("$k=$v" for (k,v) in settings), ", ")
    r = OMJulia.sendExpression(omc, "simulate($name, $setstring)")
    @test !occursin("| warning |", r["messages"])
    @test !startswith(r["messages"], "Simulation execution failed")
    es = OMJulia.sendExpression(omc, "getErrorString()")
    @test es == ""
    println(es)

    # compare simulation results to regression data
    if isfile("../regRefData/$(name)_res.csv")
        actvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"$(name)_res.csv\")")
        refvars = OMJulia.sendExpression(omc, "readSimulationResultVars(\"../regRefData/$(name)_res.csv\")")
        missingRef = setdiff(Set(actvars), Set(refvars))
        @test isempty(missingRef)
        # if variable sets differ, we should only check the variables that are present in both files
        vars = collect(intersect(Set(actvars), Set(refvars)))
        varsStr = join(map(x -> "\"$x\"", vars), ", ")
        cmd = "diffSimulationResults(\"$(name)_res.csv\", \"../regRefData/$(name)_res.csv\", \"$(name)_diff.log\", vars={ $varsStr })"
        eq, ineqAr = OMJulia.sendExpression(omc, cmd)
        @test isempty(ineqAr)
    else
        write(Base.stderr, "WARNING: no reference data for regression test of $name\n")
    end
end

omc = OMJulia.OMCSession()
try
    mopath = OMJulia.sendExpression(omc, "getModelicaPath()")
    mopath = "$mopath:$(escape_string(moroot))"
    println("Setting MODELICAPATH to ", mopath)
    OMJulia.sendExpression(omc, "setModelicaPath(\"$mopath\")")
    # load Modelica standard library
    OMJulia.sendExpression(omc, "loadModel(Modelica)")
    @testset "Simulate examples" begin
        @testset "HHmono" begin
            testmodel(omc, "HHmodelica.CompleteModels.HHmono")
        end
        @testset "HHmodHier" begin
            testmodel(omc, "HHmodelica.CompleteModels.HHmodHier")
        end
        @testset "HHmodular" begin
            testmodel(omc, "HHmodelica.CompleteModels.HHmodular")
        end
        @testset "HHmodular1p" begin
            testmodel(omc, "HHmodelica.CompleteModels.HHmodular1p")
        end
    end
finally
    println("Closing OMC session")
    sleep(1)
    OMJulia.sendExpression(omc, "quit()", parsed=false)
    println("Done")
end
