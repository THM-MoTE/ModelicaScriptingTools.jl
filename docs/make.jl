push!(LOAD_PATH,joinpath(dirname(@__FILE__),"../src/"))
using Documenter
using ModelicaScriptingTools

makedocs(sitename="ModelicaScriptingTools (MoST.jl)")
