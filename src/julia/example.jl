include("./MoST.jl")
using .MoST

omc = MoST.setupOMCSession("../../out", "../../res")
MoST.loadModel(Example)
