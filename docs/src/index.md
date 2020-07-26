# ModelicaScriptingTools (MoST.jl) Documentation

Test

## Basic utility functions

```@docs
moescape
mounescape
```

## Session handling

```@docs
setupOMCSession
closeOMCSession
withOMC
```

## Simulation

```@docs
loadModel
getSimulationSettings
getVariableFilter
simulate
```

## Testing

```@docs
testmodel
regressionTest
```

## Error handling
```@docs
MoSTError
MoSTError(::OMJulia.OMCSession, ::String)
```
