# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added

[nothing]

### Changed

[nothing]

### Fixed

[nothing]

## [1.1.0] - 2021-05-25

This is a high-level summary of the changes introduced in 1.1.0.alpha.1-5.

### Added

* Documenter.jl extension for documenting Modelica models in HTML format including
  * MathML rendering of all equations, grouped by model structure
  * table of all variables and parameters
  * HTML documentation in `annotation(Documentaion(info=...))`
* Support for OpenModelica 1.16, 1.17 and 1.18
* `installAndLoad()` function to explicitly install Modelica libraries
* `getVersion()` function to switch behavior based on OpenModelica version

### Changed

* uses custom release script instead of TagBot
* the override argument now behaves more intuitively (see v1.1.0-alpha.2)
* code is split into multiple files due to increased library size
* tests for error messages are less strict in order to better test for multiple OpenModelica versions
* Swtiched from Travis CI to GitHub actions
* `setupOMCSession` and `withOMC` now create the output directory if it does not already exist
* Modelica Standard Library is no longer loaded automatically, but must be loaded explicitly with `installAndLoad`
* documentation is deployed using `DOCUMENTER_KEY`

### Fixed

* tries to minimize freezes due to ZMQ errors in OMJulia
* models created by directly sending a definition string to the OMC could not be tested using `testmodel`

### Deprecated

* the parameter `ismodel` of `loadModel`, since we now can check if a model was loaded successfully using `getClassRestriction()` instead

### Dependencies added

* `Documenter`, since it MoST.jl now includes a Documenter extension for Modelica models
* `PyCall`, since the Documenter.jl extension requires the use of a XSLT stylesheet which is processed using the python package `lxml`
  * Note: there is currently no XSLT-capable Julia package that I am are aware of

## [1.1.0-alpha.5] - 2021-05-12

### Added

* magic line `%libs` for installing library dependencies in Documenter.jl extension

### Changed

* `installAndLoad` is now part of exported API
* no longer installs MSL by default to avoid version conflicts
* deploys docs with `DOCUMENTER_KEY`
* makes test for non-existent model less strict

## [1.1.0-alpha.4] - 05.03.2021

### Added

[nothing]

### Changed

* Documenter.jl extension now rethrows all errors which are not `MoSTError`s
* Class documentation starts with heading containing the class name
* Switched order of label and value columns in variable tables for better readability
* Switched from Travis CI to GitHub actions
* Made some unit tests less strict to avoid failing tests due to small changes between OpenModelica versions
* `testFailing.sh` now uses `--project` parameter instead of local import
* added alternative expected results for OpenModelica > 1.17.0
* the parameter `ismodel` of `loadModel` is deprecated, since we now can check if a model was loaded successfully using `getClassRestriction()` instead.

### Fixed

* `BoundError` in `commonprefix` when length of reference is exceeded
* `commonprefix` stopped one character to early
* `Manifest.toml` now gives relative link for `ModelicaScriptingTools`
* `uniquehierarchy` did not consider two distinct postfixes as unique if one was a postfix of the other on the string level
* retries creating `OMCSession` up to 10 times if an `ZMQ.StateError` is encountered
* models created by directly sending a definition string to the OMC could not be tested using `testmodel`

## [1.1.0-alpha.3] - 19.11.2020

### Added

* Support for OpenModelica 1.16.0
  - uses `--unitChecking` instead of `--preOptModules+=unitChecking`
  - ignores strange new warning `Warning: function Unit.unitString failed for "MASTER()".`
  - adds `getVersion()` function to switch behavior based on OpenModelica version
  - small changes in expected test output due to unit checking changes
  - calls `installPackage(Modelica)` if MSL is not already installed

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


[Unreleased]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.5..HEAD
[1.1.0]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.5..v1.1.0
[1.1.0-alpha.5]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.4..v1.1.0-alpha.5
[1.1.0-alpha.4]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.3..v1.1.0-alpha.4
[1.1.0-alpha.3]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.2..v1.1.0-alpha.3
[1.1.0-alpha.2]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.1.0-alpha.1..v1.1.0-alpha.2
[1.1.0-alpha.1]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v1.0.0..v1.1.0-alpha.1
[1.0.0]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v0.9.0..v1.0.0
[0.9.0]: https://github.com/CSchoel/ModelicaScriptingTools.jl/compare/v0.8.0..v0.9.0
[0.8.0]: https://github.com/CSchoel/ModelicaScriptingTools.jl/releases/tag/v0.8.0
