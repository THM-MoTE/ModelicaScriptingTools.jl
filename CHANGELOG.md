# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added

* Support for OpenModelica 1.16.0
  - uses `--unitChecking` instead of `--preOptModules+=unitChecking`
  - ignores strange new warning `Warning: function Unit.unitString failed for "MASTER()".`
  - adds `getVersion()` function to switch behavior based on OpenModelica version
  - small changes in expected test output due to unit checking changes

### Changed

[nothing]

### Fixed

[nothing]

## [1.1.0-alpha.2] - 30.10.2020

### Added

* test case for Documenter.jl extension

### Changed

* list of equations in Documenter.jl extension is now grouped by common prefix
* equations in Documenter.jl extension now use "dot operator" instead of "invisible times"
* the `override` argument now behaves more intuitively
  - adjusts the `numberOfIntervals` when only `startTime` and/or `stopTime` are changed
  - allows additional key `interval` which also changes `numberOfIntervals`
* Travis CI script now uses OpenModelica 1.14.2, because MoST.jl is not compatible with OpenModelica 1.16 yet

### Fixed

[nothing]

## [1.1.0-alpha.1]

### Added

* Experimental support for documenting Modelica models using [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).
* New dependencies:
  * PyCall (for XML handling using lxml)
  * Documenter
  * Markdown

### Changed

* Split code into multiple files.
* `setupOMCSession` and `withOMC` now create the output directory if it does not already exist

### Fixed

[nothing]

## [1.0.0]

### Added

* function `withOMC` that allows to setup a `OMCSession` that can be used with `do`
* unit tests for individual functions
* support for regression tests with `outputFormat="mat"`
* documentation using Documenter.jl
* Travis CI script

### Changed

* project structure changed to standard Julia package structure
* module name is now `ModelicaScriptingTools` instead of `MoST`
* `getVariableFilter` and `getSimulationSettings` now throw `MoSTError`s if the requested model does not exist
* use `__MoST_experiment` instead of `__ChrisS_testing` as vendor specific annotation
* `refDir` parameter in `testmodel` and `regressionTest` now is relative to CWD instead of output dir
* result of `getSimulationSettings` and parameter `settings` in `simulate` now contains unescaped values`

### Fixed

* only use `ZMQ.send` without `ZMQ.recv` for sending `quit()` to avoid freezing

## [0.9.0]

### Added

* `regressionTest` accepts new optional argument `variableFilter`
* unit checking is enabled by default using the OMC flag `--preOptModules+=unitChecking`
* unit checking can be disabled by calling `setupOMCSession(odir,mdir; checkunits=false)`


### Changed

* `testmodel` automatically sets `variableFilter` for regression test
* `getErrorString()` calls are not parsed anymore since the OMJulia lexer tends to choke on them

### Fixed

[nothing]


## [0.8.0]

### Added

* Full suite of helper functions for unit and regression tests

### Changed

[nothing]

### Fixed

[nothing]
