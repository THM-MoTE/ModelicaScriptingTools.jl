# Introduction

ModelicaScriptingTools.jl (or short MoST.jl) contains utility functions to improve the usability of [OMJulia](https://github.com/OpenModelica/OMJulia.jl).
This currently includes the following main features:

* Easy setup of `OMCSession` with configurable output and model directory
* Escaping and unescaping Modelica strings for use in `sendExpression()`
* Support for unit tests and regression tests using Julia's `Test` package

## Installation

MoST.jl is available as a Julia package with the name `ModelicaScriptingTools`.
You can install it using the Pkg REPL, which can be accessed by typing `]` in a Julia prompt.

```verbatim
pkg> add ModelicaScriptingTools
```

Alternatively you can also install MoST.jl using the following Julia commands:

```julia
using Pkg
Pkg.add("ModelicaScriptingTools")
```

## Example

The following example uses MoST.jl to test the model defined in the file `test/res/Èxample.mo` by loading and instantiating the model, performing a simulation according to the settings specified in the model file, and comparing the results, which are written in the folder `test/out`, to a reference dataset in `test/regRefData`, if such a reference file exists.

``` julia
using ModelicaScriptingTools
using Test

withOMC("test/out", "test/res") do omc
    @testset "Example" begin
        testmodel(omc, "Example"; refdir="test/regRefData")
    end
end
```
