include("./MoST.jl")
using .MoST
using Test

if !isdir("out")
    mkdir("out")
end

if !isdir("regRefData")
    mkdir("regRefData")
end

omc = MoST.setupOMCSession("out", "res")
try
    MoST.loadModel(omc, "Example")
    MoST.simulate(omc, "Example", MoST.getSimulationSettings(omc, "Example"))
    cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
    @testset "Example" begin
        MoST.testmodel(omc, "Example")
    end
finally
    MoST.closeOMCSession(omc)
end
