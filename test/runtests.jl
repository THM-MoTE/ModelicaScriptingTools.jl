using ModelicaScriptingTools: setupOMCSession, loadModel, simulate, getSimulationSettings, testmodel, closeOMCSession
using Test

if !isdir("out")
    mkdir("out")
end

if !isdir("regRefData")
    mkdir("regRefData")
end

omc = setupOMCSession("out", "../res")
try
    loadModel(omc, "Example")
    simulate(omc, "Example", getSimulationSettings(omc, "Example"))
    cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
    @testset "Example" begin
        testmodel(omc, "Example", regRelTol=1e-4)
    end
finally
    closeOMCSession(omc)
end
