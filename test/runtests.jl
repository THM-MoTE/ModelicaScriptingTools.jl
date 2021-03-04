using ModelicaScriptingTools
using Test: @testset, @test, @test_nowarn, @test_throws
using OMJulia: sendExpression
using DataFrames: Not, select!, DataFrame
using CSV
using Markdown
using Documenter

if !isdir("out")
    mkdir("out")
end

if !isdir("regRefData")
    mkdir("regRefData")
end

struct DummyPage
    source:: String
    workdir:: String
    mapping:: Dict
end

DummyPage(workdir) = DummyPage("dummydoc.md", workdir, Dict())

struct DummyInternal
    errors:: Array
end

struct DummyDocument
    internal:: DummyInternal
end

DummyDocument() = DummyDocument(DummyInternal([]))

@testset "MoST" begin
    @testset "moescape" begin
        @test raw"\\\"test\t\\data\?\\\"" == moescape("\"test\t\\data?\"")
    end
    @testset "mounescape" begin
        @test "\"test\t\\data?\"" == mounescape(raw"\\\"test\t\\data\?\\\"")
    end
    @testset "uniquehierarchy" begin
        funcnames = [
            "a.b.c",
            "x.y.c",
            "ab.cd.ec",
            "ab.cd\$c"
        ]
        hier = uniquehierarchy(funcnames)
        expected = Dict(
            "a.b.c" => "b.c",
            "x.y.c" => "y.c",
            "ab.cd.ec" => "ec",
            "ab.cd\$c" => "cd.c"
        )
        @test expected == hier
    end
    @testset "replacefuncnames" begin
        input = """
        <math xmlns="http://www.w3.org/1998/Math/MathML">
        <mrow>
            <mrow><mi> foo</mi></mrow>
            <mo>&#8801;</mo>
            <mrow>
                <mrow><mi>bla\$blubb.f</mi></mrow>
                <mo>&#8289;</mo>
                <mrow>
                    <mo>(</mo>
                    <mrow><mi> r</mi></mrow>
                    <mo>,</mo>
                    <mrow><mi> k</mi></mrow>
                    <mo>)</mo>
                </mrow>
            </mrow>
        </mrow>
        </math>"""
        replaced = replacefuncnames(input, Dict("bla\$blubb.f" => "f"))
        @test replace(input, "bla\$blubb.f" => "f") == replaced
    end
    @testset "Documenter.jl extension" begin
        @testset "DocExample" begin
            x = Markdown.parse("""
            ```@modelica
            %modeldir=res
            DocExample
            ```
            """).content[1]
            page = DummyPage(".")
            Documenter.Selectors.dispatch(
                Documenter.Expanders.ExpanderPipeline, x,
                page, DummyDocument()
            )
            result = page.mapping[x]
            @test result isa Documenter.Documents.MultiOutput
            @test length(result.content) == 6
            @test result.content[1] isa Markdown.Header{3}
            @test strip(result.content[1].text) == "DocExample"
            @test result.content[2] isa Documenter.Documents.RawHTML
            @test strip(result.content[2].code) == """
            <p>This is an example documentation for the DocExample class.</p>"""
            @test result.content[3] isa Markdown.Code
            @test replace(result.content[3].code, r"\s+" => "") == replace(read("res/DocExample.mo", String), r"\s+" => "")
            @test result.content[4] isa Documenter.Documents.RawHTML
            expected = """
            <ol><li><math xmlns="http://www.w3.org/1998/Math/MathML">
            <mrow><msup><mrow><mrow><mi> r
            </mi></mrow></mrow><mo>&#8242;</mo></msup><mo>&#8801;</mo><mrow><mn> 1.0
            </mn><mo>/</mo><mrow><mrow><mi>g</mi></mrow><mo>&#8289;</mo><mrow><mo>(</mo><mrow><mi> foo
            </mi></mrow><mo>)</mo></mrow></mrow></mrow></mrow>
            </math><li><math xmlns="http://www.w3.org/1998/Math/MathML">
            <mrow><mrow><mi> foo
            </mi></mrow><mo>&#8801;</mo><mrow><mrow><mi>f</mi></mrow><mo>&#8289;</mo><mrow><mo>(</mo><mrow><mi> r
            </mi></mrow><mo>,</mo><mrow><mi> k
            </mi></mrow><mo>)</mo></mrow></mrow></mrow>
            </math></ol>"""
            @test replace(result.content[4].code, r"\s+" => "") == replace(expected, r"\s+" => "")
            @test result.content[5] isa Markdown.MD
            @test result.content[5] == Markdown.parse("""Functions:

            ```modelica
            function f
              input Real x;
              input Real y;
              output Real res;
            algorithm
              res := x ^ y + y;
            end f;
            ```

            ```modelica
            function g
              input Real x;
              output Real y;
            algorithm
              y := 2.0 * x;
            end g;
            ```""")
            variables14 = Markdown.parse("""
            | name | unit | value |                  label |
            | ----:| ----:| -----:| ----------------------:|
            |    r |  "V" |   0.0 |         some potential |
            |  foo |      |       | second sample variable |
            |    k |      |   2.0 |         some parameter |
            """)
            variables16 = Markdown.parse("""
            | name | unit | value |                  label |
            | ----:| ----:| -----:| ----------------------:|
            |  foo |      |       | second sample variable |
            |    r |  "V" |   0.0 |         some potential |
            |    k |      |   2.0 |         some parameter |
            """)
            @test result.content[6] isa Markdown.MD
            @test result.content[6] in [variables14, variables16]
        end
        @testset "Example (model without functions)" begin
            # only checks if models without functions pose errors
            x = Markdown.parse("""
            ```@modelica
            %modeldir=res
            Example
            ```
            """).content[1]
            page = DummyPage(".")
            Documenter.Selectors.dispatch(
                Documenter.Expanders.ExpanderPipeline, x,
                page, DummyDocument()
            )
            result = page.mapping[x]
        end
    end
    withOMC("out", "res") do omc
        @testset "getVersion" begin
            major, minor, patch = getVersion(omc)
            # just test that version is sensible (and we have correct types)
            @test major >= 0
            @test minor >= 0
            @test patch >= 0
        end
        @testset "loadModel" begin
            mopath = sendExpression(omc, "getModelicaPath()")
            @testset "load existing correct model" begin
                @test_nowarn loadModel(omc, "Example")
            end
            @testset "load existing model with syntax error" begin
                modelfile = joinpath(pwd(), "res/SyntaxError.mo")
                expected = MoSTError(
                    "Could not load SyntaxError",
                    string("[$modelfile:6:3-6:3:writable] Error: Missing token: SEMICOLON\n",
                    "Error: Failed to load package SyntaxError (default) using MODELICAPATH $mopath.\n")
                )
                @test_throws expected loadModel(omc, "SyntaxError")
            end
            @testset "load existing model with instantiation error" begin
                modelfile = joinpath(pwd(), "res/UndefinedVariable.mo")
                expected = MoSTError(
                    "Model check of UndefinedVariable failed",
                    string("\n[$modelfile:3:3-3:13:writable] Error: Variable r not found in scope UndefinedVariable.\n",
                    "Error: Error occurred while flattening model UndefinedVariable\n")
                )
                @test_throws expected loadModel(omc, "UndefinedVariable")
            end
            @testset "load non-existent model" begin
                expected = MoSTError(
                    "Could not load DoesNotExist",
                    "Error: Failed to load package DoesNotExist (default) using MODELICAPATH $mopath.\n")
                @test_throws expected loadModel(omc, "DoesNotExist")
            end
        end
        @testset "getSimulationSettings" begin
            loadModel(omc, "Example")
            @testset "read from model file" begin
                res = Dict(
                    "startTime" => 0.0, "stopTime" => 5.0,
                    "numberOfIntervals" => 50, "outputFormat" => "csv",
                    "variableFilter" => "sub\\.alias",
                    "tolerance" => 1.0e-6
                )
                @test res == getSimulationSettings(omc, "Example")
            end
            @testset "use override" begin
                @test 1 == getSimulationSettings(omc, "Example"; override=Dict("startTime" => 1))["startTime"]
            end
            @testset "nonexistant model" begin
                @test_throws MoSTError getSimulationSettings(omc, "DoesNotExist")
            end
        end
        @testset "simulate" begin
            mopath = sendExpression(omc, "getModelicaPath()")
            @testset "simulate correct model" begin
                loadModel(omc, "Example")
                @test_nowarn simulate(omc, "Example")
            end
            @testset "simulate model with arithmetic error" begin
                loadModel(omc, "ArithmeticError")
                expected = MoSTError(
                    "Simulation of ArithmeticError failed",
                    string("Simulation execution failed for model: ArithmeticError\n",
                    "LOG_SUCCESS       | info    | The initialization finished successfully without homotopy method.\n",
                    "assert            | debug   | division by zero at time 1.000000000200016, (a=1) / (b=0), ",
                    "where divisor b expression is: x\n")
                )
                @test_throws expected simulate(omc, "ArithmeticError")
            end
            @testset "simulate model with initialization warning" begin
                loadModel(omc, "MissingInitialValue")
                expected = MoSTError(
                    "Simulation of MissingInitialValue failed",
                    string("Warning: The initial conditions are not fully specified. ",
                    "For more information set -d=initialization. ",
                    "In OMEdit Tools->Options->Simulation->OMCFlags, ",
                    "in OMNotebook call setCommandLineOptions(\"-d=initialization\").\n"
                    )
                )
                @test_throws expected simulate(omc, "MissingInitialValue")
            end
            @testset "simulate model with inconsistent units" begin
                expected = if getVersion(omc) >= Tuple([1, 16, 0])
                    MoSTError(
                        "Model InconsistentUnits could not be instantiated",
                        string("Warning: The following equation is INCONSISTENT due to specified unit information:  sub.alias = r;",
                        "\nWarning: The units of following sub-expressions need to be equal:",
                        "\n- sub-expression \"r\" has unit \"A\"",
                        "\n- sub-expression \"sub.alias\" has unit \"V\"\n")
                    )
                else
                    MoSTError(
                        "Simulation of InconsistentUnits failed",
                        string("Warning: The following equation is INCONSISTENT due to specified unit information: sub.alias = r",
                        "\nThe units of following sub-expressions need to be equal:",
                        "\n- sub-expression \"r\" has unit \"A\"",
                        "\n- sub-expression \"sub.alias\" has unit \"V\"\n")
                    )
                end
                try
                    # OpenModelica 1.16 error occurs here
                    loadModel(omc, "InconsistentUnits")
                    # OpenModelica 1.15 / 1.14 error occurs here
                    simulate(omc, "InconsistentUnits")
                catch actual
                    @test isa(actual, MoSTError)
                    @test actual.msg == expected.msg
                    # replace start of line that contains error location
                    actomc = replace(actual.omc, r"^\[.*\]\s+" => "")
                    for (a, e) in zip(split(actomc, "\n"), split(expected.omc, "\n"))
                        @test a == e
                    end
                end
            end
        end
        @testset "regressionTest" begin
            @testset "helper function resamplequi" begin
                testdata = DataFrame(
                    "time" => range(0, 1; length=10),
                    "x" => range(4, 10; length=10)
                )
                expected = DataFrame(
                    "time" => [0, 0.5, 1],
                    "x" => [testdata[1, "x"], testdata[6, "x"], testdata[10, "x"]]
                )
                @test expected == ModelicaScriptingTools.resamplequi(testdata, 3)
            end
            # we can only test correct regression test here
            @testset "regression tests of correct model" begin
                # setup simulation and reference data
                loadModel(omc, "Example")
                simulate(omc, "Example")
                cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
                regressionTest(omc, "Example", "regRefData"; relTol=1e-3, variableFilter="sub\\.alias")
            end
            @testset "regression test with missing alias in reference" begin
                # setup simulation and reference data
                loadModel(omc, "Example")
                simulate(omc, "Example")
                cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
                # remove column r from reference data, which should not have been selected in the first place
                csvfile = "regRefData/Example_res.csv"
                data = DataFrame(CSV.File(csvfile))
                select!(data, Not(:r))
                CSV.write(csvfile, data)
                regressionTest(omc, "Example", "regRefData"; relTol=1e-3, variableFilter="sub\\.alias")
            end
            @testset "regression test with ouputFormat=mat" begin
                # setup simulation and reference data
                loadModel(omc, "Example")
                simulate(omc, "Example", getSimulationSettings(omc, "Example"; override=Dict("outputFormat" => "mat")))
                cp("out/Example_res.mat", "regRefData/Example_res.mat"; force=true)
                regressionTest(omc, "Example", "regRefData"; relTol=1e-3, variableFilter="sub\\.alias", outputFormat="mat")
            end
        end
        @testset "testmodel" begin
            loadModel(omc, "Example")
            simulate(omc, "Example", getSimulationSettings(omc, "Example"))
            cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
            testmodel(omc, "Example", regRelTol=1e-4)
        end
        @testset "getDocAnnotation" begin
            loadModel(omc, "Example")
            expected = "\n        <p>This is an example documentation for the Example class.</p>\n      "
            @test expected == getDocAnnotation(omc, "Example")
        end
        @testset "getcode" begin
            loadModel(omc, "Example.ExSub")
            expected = """model ExSub
              Modelica.SIunits.Voltage alias;
            end ExSub;"""
            @test expected == getcode(omc, "Example.ExSub")
        end
        @testset "getequations" begin
            loadModel(omc, "Example")
            expected = [
                "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n<mrow><msup><mrow><mrow><mi> r \n</mi></mrow></mrow><mo>&#8242;</mo></msup><mo>&#8801;</mo><mn> 1.0 \n</mn></mrow>\n</math>"
            ]
            @test expected == getequations(omc, "Example")
        end
        @testset "deprefix" begin
            @testset "FunctionNames" begin
                loadModel(omc, "FunctionNames")
                vars = getvariables(omc, "FunctionNames")
                adict = ModelicaScriptingTools.aliasdict(vars)
                eqs = getequations(omc, "FunctionNames")
                funcs = getfunctions(omc, "FunctionNames")
                (funcdict, funcs) = uniquefunctions(funcs)
                eqs = [replacefuncnames(e, funcdict) for e in eqs]
                funcdict = uniquehierarchy(funcs[1:end, 1])
                eqs = [replacefuncnames(e, funcdict) for e in eqs]
                prefixes = [commonhierarchy(e, adict) for e in eqs]
                de = [deprefix(e, p) for (e, p) in zip(eqs, prefixes)]
                @test ["x", "_f", "_b", "_f", "_b"] == findidentifiers(de[1])
                @test ["_b", "_f", "x", "g", "x"] == findidentifiers(de[2])
            end
        end
        @testset "getvariables" begin
            loadModel(omc, "Example")
            expected = [
                Dict(
                    "label" => "", "name" => "r",
                    "variability" => "continuousState", "unit" => "\"V\"",
                    "initial" => "0.0", "type" => "Real",
                    "quantity" => "\"ElectricPotential\"",
                    "bindExpression" => "", "aliasof" => ""
                ),
                Dict(
                    "label" => "", "name" => "sub.alias",
                    "variability" => "continuous", "unit" => "\"V\"",
                    "initial" => "", "type" => "Real",
                    "quantity" => "\"ElectricPotential\"",
                    "bindExpression" => "r", "aliasof" => "r"
                )
            ]
            @test expected == getvariables(omc, "Example")
        end
        @testset "getfunctions" begin
            @testset "DocExample" begin
                loadModel(omc, "DocExample")
                expected = [
                    "DocExample.f" "function(x :: Real * y :: Real) => Real" "function DocExample.f\n  input Real x;\n  input Real y;\n  output Real res;\nalgorithm\n  res := x ^ y + y;\nend DocExample.f;\n\n\n";
                    "DocExample.g" "function(x :: Real) => Real" "function DocExample.g\n  input Real x;\n  output Real y;\nalgorithm\n  y := 2.0 * x;\nend DocExample.g;\n\n\n"
                ]
                @test expected == getfunctions(omc, "DocExample")
            end
            @testset "FunctionNames" begin
                loadModel(omc, "FunctionNames")
                funcs = getfunctions(omc, "FunctionNames")
                expected = [
                    "FunctionNames.f", "FunctionNames.f2", "FunctionNames.Submodel\$sm.f",
                    "FunctionNames.Submodel\$sm.g", "FunctionNames.Submodel\$sm.f.inf",
                    "FunctionNames.f.inf", "FunctionNames.f2.inf"
                ]
                @test expected == funcs[:, 1]
            end
        end
        @testset "funclist" begin
            loadModel(omc, "FunctionNames")
            funcs = getfunctions(omc, "FunctionNames")
            funclist = functionlist(funcs)
            expected = Markdown.parse("""Functions:

            ```modelica
            function inf
              input Real x;
              input Real a = 1.0;
              output Real y;
            algorithm
              y := x + a;
            end inf;
            ```

            ```modelica
            function g
              input Real x;
              output Real y;
            algorithm
              y := 1.0 + x;
            end g;
            ```

            ```modelica
            function sm.f
              input Real x1;
              input Real x2 = 1.0;
              output Real y;
            algorithm
              y := 2.0 * x1 + inf(x2, 1.0);
            end sm.f;
            ```
            """)
            @test expected == funclist
        end
    end
end
