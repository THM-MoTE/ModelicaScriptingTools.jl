# ModelicaScriptingTools.jl

[![Build Status](https://travis-ci.com/THM-MoTE/ModelicaScriptingTools.jl.svg?branch=master)](https://travis-ci.com/THM-MoTE/ModelicaScriptingTools.jl)
[![codecov](https://codecov.io/gh/THM-MoTE/ModelicaScriptingTools.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/THM-MoTE/ModelicaScriptingTools.jl)
[![Documentation stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thm-mote.github.io/ModelicaScriptingTools.jl/dev/)


![MoST.jl](docs/src/assets/logo.svg)

ModelicaScriptingTools.jl (or short MoST.jl) contains utility functions to improve the usability of [OMJulia](https://github.com/OpenModelica/OMJulia.jl).
This currently includes the following main features:

* Easy setup of `OMCSession` with configurable output and model directory
* Escaping and unescaping Modelica strings for use in `sendExpression()`
* Support for unit tests and regression tests using Julia's `Test` package

## Documentation

The [documentation](https://thm-mote.github.io/ModelicaScriptingTools.jl/dev/) can be found on GitHub pages.

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

### Python dependencies

This module has additional dependencies to python modules via PyCall.
If you get an error message that looks something like this

```verbatim
The Python package lxml could not be found by pyimport. Usually this means
that you did not install lxml in the Python version being used by PyCall.

PyCall is currently configured to use the Python version at:

/usr/bin/python3
```

you should follow the advice at the end of the error message and use the following command from the command line.

```
julia -e 'ENV["PYTHON"]=""; using Pkg; Pkg.build("PyCall")'
```

so that PyCall can manage the required python modules in a private Anaconda installation.

Alternatively you can, of course, also install the required modules (which are listed in the file `requirements.txt`) in the same way that you would normally use to install python packages (`apt-get`, `pip`, `conda`, ...).

## Example

The following example uses MoST.jl to test the model defined in the file `test/res/Èxample.mo` by loading and instantiating the model, performing a simulation according to the settings specified in the model file, and comparing the results, which are written in the folder `test/out`, to a reference dataset in `test/regRefData`, if such a reference file exists.

``` julia
using ModelicaScriptingTools
using Test

withOMC("test/out", "test/res") do omc
    @testset "Example" begin
        testmodel(omc, "Example"; refDir="test/regRefData")
    end
end
```
