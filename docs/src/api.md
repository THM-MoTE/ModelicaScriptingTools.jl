# API

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
installAndLoad
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

## Documentation
```@docs
getDocAnnotation
getcode
getequations
getvariables
mdescape
variabletable
```
