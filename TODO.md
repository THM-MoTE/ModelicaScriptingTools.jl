# TODO list

* consistent ordering of equations (do not count groups)
* handle when equations properly in documentation
* use full group name in "Within group ..." text
* parse unit definitions and display as MathML
* shorten function names
  * proposed algorithm: use part after last dot and add number to disambiguate
* group functions with identical algorithms section
* display list of functions in documentation (with original name)
* make float values human-readable by (optionally) restricting precision
* add a proper header for Modelica autodoc entries (including docstring of class)
* add possibility to show equations and variables of non-instantiatable classes
* add diagrams to output
  * must be done with something like https://github.com/OpenModelica/OpenModelica/blob/master/OMCompiler/Examples/generate_icons.py
  * maybe using Luxor.jl?
  * reference for how OMEdit handles drawing: https://github.com/OpenModelica/OMEdit/tree/master/OMEdit/OMEditGUI/Annotations
  * idea: use OMC to parse for components, equations, and parents of a class
* add tooltip to variables and parameters in equation list
