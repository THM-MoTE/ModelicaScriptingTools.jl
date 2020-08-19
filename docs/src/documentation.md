# Documenter.jl extension

MoST.jl allows to generate documentation for Modelica models with [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).

## Quick start

To use the Documenter.jl extensions, you have to follow the [Documenter.jl Guide](https://juliadocs.github.io/Documenter.jl/stable/man/guide/) for setting up a documentation folder in your project.
Within the file `make.jl` you then have to add the line `using ModelicaScriptingTools`.

You can now add a piece of code like the following in your markdown files:

````
```@modelica
%modeldir = ../../src
MyPackage.MyFirstModel
MyOtherPackage.MySecondModel
```
````

This will display documentation for the two models `MyPackage.MyFirstModel` and `MyOtherPackage.MySecondModel` which are both assumed to be found in the folder `../../src`, which is relative to the working directory where Documenter.jl places its output (usually a folder called `build` in the directory where `make.jl` is located).

## Detailed setup guide

[WIP] This section of the documentation is work in progress.

* `julia -e 'using DocumenterTools; DocumenterTools.generate("docs"; name="MyModelicaProject")'`
* `julia --project=docs/ -e 'using Pkg; Pkg.add("ModelicaScriptingTools")'`
* Replace `using MyModelicaProject` with `using ModelicaScriptingTools` in `docs/make.jl`.
* Also change `[MyModelicaProject]` to `Module[]` in `make.jl`.

## Features and Example

The following shows the documentation of the model `DocExample.mo` in the folder `test/res` of this project.

```@modelica
%outdir=../../test/out
%modeldir = ../../test/res
DocExample
```

Currently, the documentation features

* The full code of the model.
* A list of all equations of the model as presentation MathML (only available if the model can be instantiated using the [`instantiateModel()`](https://www.openmodelica.org/doc/OpenModelicaUsersGuide/latest/scripting_api.html#instantiatemodel) function of the OpenModelica Scripting API)
* A table listing all variables and parameters of the model (also only available if the model can be instantiated)


### Configuration with magic lines

The behavior of the MoST.jl documentation feature can be adjusted using "magic" lines that start with a `%`.
These lines are not interpreted as model names, but instead are parsed to set configuration variables.

* `%modeldir = some/dir` changes the directory from which models are loaded, which is given relative to the working directory where Documenter.jl places its output (usually a folder called `build` in the directory where `make.jl` is located).
    The default location is `../`, which means that if your documentation lies in `docs` and your models are saved in the root directory of your project, you do not need to add this magic line.

    If two or more of these lines are present, the last directory is used for the whole block.
    If you need to load two models from separate directories, you need to use two separate `@modelica` blocks.
