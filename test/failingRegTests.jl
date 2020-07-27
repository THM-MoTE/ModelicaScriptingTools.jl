# tests that tests in regressionTest fail if regression reference data does not fit simulation data
# TODO find out if we can somehow run this with Pkg so we don't have to do the local import
push!(LOAD_PATH,joinpath(dirname(@__FILE__),"../src/"))
using ModelicaScriptingTools
using Test
using CSV
using DataFrames

MoST = ModelicaScriptingTools

outdir = "test/out"
modeldir = "test/res"
refdir = "test/regRefData"

function removeColumn(csvfile, colname)
    data = CSV.read(csvfile)
    select!(data, Not(Symbol(colname)))
    CSV.write(csvfile, data)
end
function multiplyColumn(csvfile, colname, factor)
    data = CSV.read(csvfile)
    data[!, Symbol(colname)] = data[Symbol(colname)] .* factor
    CSV.write(csvfile, data)
end
function resetFiles()
    cp("$outdir/TwoVarExample_res.bak.csv", "$refdir/TwoVarExample_res.csv"; force=true)
    cp("$outdir/TwoVarExample_res.bak.csv", "$outdir/TwoVarExample_res.csv"; force=true)
end

MoST.withOMC(outdir, modeldir) do omc
    # setup simulation and reference data
    MoST.loadModel(omc, "TwoVarExample")
    MoST.simulate(omc, "TwoVarExample")
    cp("$outdir/TwoVarExample_res.csv", "$outdir/TwoVarExample_res.bak.csv"; force=true)
    @testset "regressionTest" begin
        @testset "fails because of missing simulation variables" begin
            resetFiles()
            removeColumn("$outdir/TwoVarExample_res.csv", "i")
            MoST.regressionTest(omc, "TwoVarExample", refdir; relTol=1e-3, variableFilter="i|v")
        end
        @testset "fails because of missing reference variables" begin
            resetFiles()
            removeColumn("$refdir/TwoVarExample_res.csv", "i")
            MoST.regressionTest(omc, "TwoVarExample", refdir; relTol=1e-3, variableFilter="i|v")
        end
        @testset "fails because values are unequal" begin
            resetFiles()
            multiplyColumn("$outdir/TwoVarExample_res.csv", "i", 1.1)
            MoST.regressionTest(omc, "TwoVarExample", refdir; relTol=1e-3, variableFilter="i|v")
        end
    end
end
