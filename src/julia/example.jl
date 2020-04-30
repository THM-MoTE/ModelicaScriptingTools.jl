include("./MoST.jl")
using .MoST

if !isdir("out")
    mkdir("out")
end
omc = MoST.setupOMCSession("out", "res")
MoST.loadModel(omc, "Example")
MoST.simulate(omc, "Example", MoST.getSimulationSettings(omc, "Example"))
MoST.closeOMCSession(omc)
