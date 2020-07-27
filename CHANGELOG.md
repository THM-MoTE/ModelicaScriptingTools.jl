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

## [1.2.0]

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

## [1.1.0]

### Added

* `regressionTest` accepts new optional argument `variableFilter`
* unit checking is enabled by default using the OMC flag `--preOptModules+=unitChecking`
* unit checking can be disabled by calling `setupOMCSession(odir,mdir; checkunits=false)`


### Changed

* `testmodel` automatically sets `variableFilter` for regression test
* `getErrorString()` calls are not parsed anymore since the OMJulia lexer tends to choke on them

### Fixed

[nothing]


## [1.0.0]

### Added

* Full suite of helper functions for unit and regression tests

### Changed

[nothing]

### Fixed

[nothing]
