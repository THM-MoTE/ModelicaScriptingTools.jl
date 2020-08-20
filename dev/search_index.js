var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/#Basic-utility-functions","page":"API","title":"Basic utility functions","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"moescape\nmounescape","category":"page"},{"location":"api/#ModelicaScriptingTools.moescape","page":"API","title":"ModelicaScriptingTools.moescape","text":"moescape(s:: String)\n\nEscapes string according to Modelica specification for string literals.\n\nEscaped characters are: ['\\\\', '\"', '?', '\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v',]\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.mounescape","page":"API","title":"ModelicaScriptingTools.mounescape","text":"moescape(s:: String)\nmoescape(io:: IO, s:: String)\n\nUnescapes string that was escaped by moescape(s:: String) or that was returned from the OMC compiler. If io is given the string is printed to the IO object, otherwise it is returned directly.\n\n\n\n\n\n","category":"function"},{"location":"api/#Session-handling","page":"API","title":"Session handling","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"setupOMCSession\ncloseOMCSession\nwithOMC","category":"page"},{"location":"api/#ModelicaScriptingTools.setupOMCSession","page":"API","title":"ModelicaScriptingTools.setupOMCSession","text":"setupOMCSession(outdir, modeldir; quiet=false, checkunits=true)\n\nCreates an OMCSession and prepares it by preforming the following steps:\n\ncreate the directory outdir if it does not already exist\nchange the working directory of the OMC to outdir\nadd modeldir to the MODELICAPATH\nenable unit checking with the OMC command line option   --preOptModules+=unitChecking (unless checkunits is false)\nload the modelica standard library (loadModel(Modelica))\n\nIf quiet is false, the resulting MODELICAPATH is printed to stdout.\n\nReturns the newly created OMCSession.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.closeOMCSession","page":"API","title":"ModelicaScriptingTools.closeOMCSession","text":"closeOMCSession(omc:: OMCSession; quiet=false)\n\nCloses the OMCSession given by omc, shutting down the OMC instance.\n\nDue to a bug in the current release version of OMJulia the function may occasionally freeze. If this happens, you have to stop the execution with CTRL-C. You can tell that this is the case if the output Closing OMC session is printed to stdout, but it is not followed by Done. If desired, these outputs can be disabled by setting quiet=true.\n\nIf you want to use a MoST.jl script for continuous integration, you can use the following shell command to add a timeout to your script and treat the timeout as a successful test run (which is, of course, unsafe).\n\n(timeout 2m julia myTestScript.jl; rc=$?; if [ ${rc} -eq 124 ]; then exit 0; else exit ${rc}; fi;)\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.withOMC","page":"API","title":"ModelicaScriptingTools.withOMC","text":"withOMC(f:: Function, outdir, modeldir; quiet=false, checkunits=true)\n\nAllows to use OMCSession with do-block syntax, automatically closing the session after the block has been executed. For the parameter definition see setupOMCSession(outdir, modeldir; quiet=false, checkunits=true).\n\nExample:\n\nwithOMC(\"test/out\", \"test/res\") do omc\n    loadModel(omc, \"Example\")\nend\n\n\n\n\n\n","category":"function"},{"location":"api/#Simulation","page":"API","title":"Simulation","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"loadModel\ngetSimulationSettings\ngetVariableFilter\nsimulate","category":"page"},{"location":"api/#ModelicaScriptingTools.loadModel","page":"API","title":"ModelicaScriptingTools.loadModel","text":"loadModel(omc:: OMCSession, name:: String; check=true, instantiate=true)\n\nLoads the model with fully qualified name name from a source file available from the model directory. Note that this refers to the model name, not the model file.\n\nExample:\n\nloadModel(omc, \"Modelica.SIunits.Voltage\")\n\nThis function will actually call several OM scripting functions to ensure that as many errors in the model are caught and thrown as MoSTErrors as possible:\n\nFirst, loadModel(name) is called to load the model if it exists. This   call does only fail if the toplevel model does not exist. E.g.,   loadModel(Modelica.FooBar) would still return true, because Modelica   could be loaded, although FooBar does not exist.\nWe then check with isModel(name) if the model actually exists.\nWith checkModel(name) we find errors such as missing or mistyped variables.\nFinally, we use instantiateModel(name) which can sometimes find additional   errors in the model structure.\n\nIf ismodel, check, or instantiate are false, the loading process is stopped at the respective steps.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.getSimulationSettings","page":"API","title":"ModelicaScriptingTools.getSimulationSettings","text":"getSimulationSettings(omc:: OMCSession, name:: String; override=Dict())\n\nReads simulation settings from the model name. Any content in override will override the setting with the respective key.\n\nReturns a Dict with the keys \"startTime\", \"stopTime\", \"tolerance\", \"numberOfIntervals\", \"outputFormat\" and \"variableFilter\". If any of these settings are not defined in the model file, they will be filled with default values.\n\nThrows a MoSTError if the model name was not loaded beforehand using loadModel(omc:: OMCSession, name:: String).\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.getVariableFilter","page":"API","title":"ModelicaScriptingTools.getVariableFilter","text":"getVariableFilter(omc:: OMCSession, name:: String)\n\nReads the value for the variableFilter simulation setting from the model file if it has been defined. MoST assumes that this value will be given in a vendor-specific annotation of the form __MoST_experiment(variableFilter=\".*\"). If such an annotation is not found, the default filter \".*\" is returned.\n\nThrows a MoSTError if the model name does not exist.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.simulate","page":"API","title":"ModelicaScriptingTools.simulate","text":"simulate(omc:: OMCSession, name::String)\nsimulate(omc:: OMCSession, name::String, settings:: Dict{String, Any})\n\nSimulates the model name which must have been loaded before with loadModel(omc:: OMCSession, name:: String). The keyword-parameters in settings are directly passed to the OpenModelica scripting function simulate(). If the parameter is not given, it is obtained using getSimulationSettings(omc:: OMCSession, name:: String; override=Dict()).\n\nThe simulation output will be written to the current working directory of the OMC that has been set by setupOMCSession(outdir, modeldir; quiet=false, checkunits=true).\n\nThe simulation result is checked for errors with the following methods:\n\nThe messages returned by the OM scripting call are checked for   the string Simulation execution failed. This will, e.g., be the case   if there is an arithmetic error during simulation.\nThe abovementioned messages are checked for the string | warning | which   hints at missing initial values and other non-critical errors.\nThe error string returned by the OM scripting function getErrorString()   should be empty if the simulation was successful.\n\nIf any of the abovementioned methods reveals errors, a MoSTError is thrown.\n\n\n\n\n\n","category":"function"},{"location":"api/#Testing","page":"API","title":"Testing","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"testmodel\nregressionTest","category":"page"},{"location":"api/#ModelicaScriptingTools.testmodel","page":"API","title":"ModelicaScriptingTools.testmodel","text":"testmodel(omc, name; override=Dict(), refdir=\"regRefData\", regRelTol:: Real= 1e-6)\n\nPerforms a full test of the model named name with the following steps:\n\nLoad the model using loadModel(omc:: OMCSession, name:: String) (called inside @test)\nSimulate the model using simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any}) (called inside @test)\nIf a reference file exists in refdir, perform a regression test with   regressionTest(omc:: OMCSession, name:: String, refdir:: String; relTol:: Real = 1e-6, variableFilter:: String = \"\", outputFormat=\"csv\").\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.regressionTest","page":"API","title":"ModelicaScriptingTools.regressionTest","text":"regressionTest(\n    omc:: OMCSession, name:: String, refdir:: String;\n    relTol:: Real = 1e-6, variableFilter:: String = \"\", outputFormat=\"csv\"\n)\n\nPerforms a regression test that ensures that variable values in the simulation output are approximately equal to variables in the reference file in the directory given by refdir. Both the simulation output and the reference file must have the standard name \"$(name)_res.$outputFormat\". This function also assumes that the simulation a simulation of the model named name has already been run with simulate(omc:: OMCSession, name::String, settings:: Dict{String, Any}).\n\nThe test consists of the following checks performed with @test:\n\nAre there no variables in the simulation output that have no corresponding   variable in the reference file? For this check, variables are ignored that   occur in the simulation file but should not have been selected by the   regex variableFilter. This can happen in OpenModelica, because sometimes   alias variables are added to the output even though they do not match the   variableFilter.\nAre there no variables in the reference file that have no corresponding   variable in the simulation output?\nIs the intersection of common variables in both files nonempty?\nIs the length of the simulation output equal to the length of the reference   file?\nAre there any variables in the simulation file that do not satisfy   isapprox(act, ref, rtol=relTol) for all values?\n\nNOTE: There is a OM scripting function compareSimulationResults() that could be used for this task, but it is not documented and does not react to changes of its relTol parameter in a predictable way.\n\n\n\n\n\n","category":"function"},{"location":"api/#Error-handling","page":"API","title":"Error handling","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"MoSTError\nMoSTError(::OMJulia.OMCSession, ::String)","category":"page"},{"location":"api/#ModelicaScriptingTools.MoSTError","page":"API","title":"ModelicaScriptingTools.MoSTError","text":"MoSTError\n\nError class for OMJulia-related errors that contains the OMC error message.\n\n\n\n\n\n","category":"type"},{"location":"api/#ModelicaScriptingTools.MoSTError-Tuple{OMJulia.OMCSession,String}","page":"API","title":"ModelicaScriptingTools.MoSTError","text":"MoSTError(omc:: OMCSession, msg:: String)\n\nCreates MoSTError with message msg and current result of getErrorString() as OMC error message.\n\n\n\n\n\n","category":"method"},{"location":"api/#Documentation","page":"API","title":"Documentation","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"getDocAnnotation\ngetcode\ngetequations\ngetvariables\nmdescape\nvariabletable","category":"page"},{"location":"api/#ModelicaScriptingTools.getDocAnnotation","page":"API","title":"ModelicaScriptingTools.getDocAnnotation","text":"getDocAnnotation(omc:: OMCSession, name:: String)\n\nReturns documentation string from model annotation and strips <html> tag if necessary.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.getcode","page":"API","title":"ModelicaScriptingTools.getcode","text":"getcode(omc:: OMCSession, model:: String)\n\nReturns the code of the given model or class as a string.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.getequations","page":"API","title":"ModelicaScriptingTools.getequations","text":"getequations(omc:: OMCSession, model::String)\n\nReturns all equations of the given model as a list of strings with presentation MathML syntax.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.getvariables","page":"API","title":"ModelicaScriptingTools.getvariables","text":"getvariables(omc:: OMCSession, model::String)\n\nReturns an array of dictionaries that contain the following keys describing the variables and parameters of the given model.\n\n\"name\": the name of the variable\n\"variability\": is the variable a parameter, a constant, or a variable?\n\"type\": the data type of the variable (usually \"Real\")\n\"label\": the string label attached to the variable\n\"quantity\": the kind of physical quantity modeled by the variable\n\"unit\": the unit of the variable in Modelica unit syntax\n\"initial\": the initial value of the variable, if existent\n\"bindExpression\": the expression used to fix the variable value, if existent\n\"aliasof\": the name of the other variable of which this variable is an alias\n\nAn empty string is used as value for keys which are not applicable for the given variable.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.mdescape","page":"API","title":"ModelicaScriptingTools.mdescape","text":"mdescape(s:: String)\n\nEscapes characters that have special meaning in Markdown with a backslash.\n\n\n\n\n\n","category":"function"},{"location":"api/#ModelicaScriptingTools.variabletable","page":"API","title":"ModelicaScriptingTools.variabletable","text":"variabletable(vars:: Array{Dict{Any, Any},1})\n\nCreates a Markdown table from an array of variable descriptions as returned by getvariables(omc:: OMCSession, model::String).\n\n\n\n\n\n","category":"function"},{"location":"#Introduction","page":"Introduction","title":"Introduction","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"ModelicaScriptingTools.jl (or short MoST.jl) contains utility functions to improve the usability of OMJulia. This currently includes the following main features:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Easy setup of OMCSession with configurable output and model directory\nEscaping and unescaping Modelica strings for use in sendExpression()\nSupport for unit tests and regression tests using Julia's Test package","category":"page"},{"location":"#Installation","page":"Introduction","title":"Installation","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"MoST.jl is available as a Julia package with the name ModelicaScriptingTools. You can install it using the Pkg REPL, which can be accessed by typing ] in a Julia prompt.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"pkg> add ModelicaScriptingTools","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Alternatively you can also install MoST.jl using the following Julia commands:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using Pkg\nPkg.add(\"ModelicaScriptingTools\")","category":"page"},{"location":"#Example","page":"Introduction","title":"Example","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"The following example uses MoST.jl to test the model defined in the file test/res/Èxample.mo by loading and instantiating the model, performing a simulation according to the settings specified in the model file, and comparing the results, which are written in the folder test/out, to a reference dataset in test/regRefData, if such a reference file exists.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using ModelicaScriptingTools\nusing Test\n\nwithOMC(\"test/out\", \"test/res\") do omc\n    @testset \"Example\" begin\n        testmodel(omc, \"Example\"; refDir=\"test/regRefData\")\n    end\nend","category":"page"},{"location":"documentation/#Documenter.jl-extension","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"MoST.jl allows to generate documentation for Modelica models with Documenter.jl.","category":"page"},{"location":"documentation/#Quick-start","page":"Documenter.jl extension","title":"Quick start","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"To use the Documenter.jl extensions, you have to follow the Documenter.jl Guide for setting up a documentation folder in your project. Within the file make.jl you then have to add the line using ModelicaScriptingTools.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"You can now add a piece of code like the following in your markdown files:","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"```@modelica\n%modeldir = ../../src\nMyPackage.MyFirstModel\nMyOtherPackage.MySecondModel\n```","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"This will display documentation for the two models MyPackage.MyFirstModel and MyOtherPackage.MySecondModel which are both assumed to be found in the folder ../../src, which is relative to the working directory where Documenter.jl places its output (usually a folder called build in the directory where make.jl is located).","category":"page"},{"location":"documentation/#Detailed-setup-guide","page":"Documenter.jl extension","title":"Detailed setup guide","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"warning: Warning\nThis section of the documentation is work in progress.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"julia -e 'using DocumenterTools; DocumenterTools.generate(\"docs\"; name=\"MyModelicaProject\")'\njulia --project=docs/ -e 'using Pkg; Pkg.add(\"ModelicaScriptingTools\")'\nReplace using MyModelicaProject with using ModelicaScriptingTools in docs/make.jl.\nAlso change [MyModelicaProject] to Module[] in make.jl.","category":"page"},{"location":"documentation/#Deploy-docs-with-Travis-CI","page":"Documenter.jl extension","title":"Deploy docs with Travis CI","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"warning: Warning\nThis section of the documentation is work in progress.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"Add this to make.jl:   deploydocs(       repo = \"github.com/MyGithubUsername/MyRepo.git\",   )\nAdd this to .travis.yml\n- export PYTHON=\"\"\n- julia --project=docs/ -e \"using Pkg; Pkg.instantiate()\"\n- julia --project=docs/ docs/make.jl\njulia -e 'using DocumenterTools; DocumenterTools.genkeys(user=\"MyGithubUsername\", repo=\"MyRepo\")'\nFollow instructions","category":"page"},{"location":"documentation/#Features-and-Example","page":"Documenter.jl extension","title":"Features and Example","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"The following shows the documentation of the model DocExample.mo in the folder test/res of this project.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"%outdir=../../test/out\n%modeldir = ../../test/res\nDocExample","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"Currently, the documentation features","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"The HTML documentation in the Documentation(info=...) anotation.\nThe full code of the model.\nA list of all equations of the model as presentation MathML (only available if the model can be instantiated using the instantiateModel() function of the OpenModelica Scripting API)\nA table listing all variables and parameters of the model (also only available if the model can be instantiated)","category":"page"},{"location":"documentation/#Configuration-with-magic-lines","page":"Documenter.jl extension","title":"Configuration with magic lines","text":"","category":"section"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"The behavior of the MoST.jl documentation feature can be adjusted using \"magic\" lines that start with a %. These lines are not interpreted as model names, but instead are parsed to set configuration variables.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"%modeldir = some/dir changes the directory from which models are loaded, which is given relative to the working directory where Documenter.jl places its output (usually a folder called build in the directory where make.jl is located).   The default location is ../, which means that if your documentation lies in docs and your models are saved in the root directory of your project, you do not need to add this magic line.\n%outdir = some/dir changes the directory where output files will be placed.   Like modeldir, it is given relative to the working directory of Documenter.jl.   The default\n%nocode removes the model source code from the documentation output.\n%noequations removes the list of equations and variables from the documentation output.   This is a required step for models that cannot be instantiated using instantiateModel().\n%noinfo removes the content of the Documentation(info=...) annotation from the documentation output.","category":"page"},{"location":"documentation/","page":"Documenter.jl extension","title":"Documenter.jl extension","text":"note: Note\nMagic lines always change the behavior of the whole @modelica block, regardless where they appear in the block. If the same type of line occurs multiple times, the last value takes precedence. If you need to load two models with separate settings, you therefore need to use two separate @modelica blocks.","category":"page"}]
}
