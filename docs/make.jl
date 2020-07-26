push!(LOAD_PATH,joinpath(dirname(@__FILE__),"../src/"))
using Documenter
using ModelicaScriptingTools
using OMJulia

makedocs(
    sitename="ModelicaScriptingTools.jl",
    pages = [
        "index.md",
        "api.md"
    ]
)
deploydocs(
    repo = "github.com/THM-MoTE/MoST.jl.git",
)
