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
                <mrow><mi>bla.f</mi></mrow>
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
        replaced = replacefuncnames(input, Dict("bla.f" => "f"))
        @test replace(input, "bla.f" => "f") == replaced
    end
    @testset "Documenter.jl extension" begin
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
        @test length(result.content) == 5
        @test result.content[1] isa Documenter.Documents.RawHTML
        @test strip(result.content[1].code) == """
        <p>This is an example documentation for the DocExample class.</p>"""
        @test result.content[2] isa Markdown.Code
        @test replace(result.content[2].code, r"\s+" => "") == replace(read("res/DocExample.mo", String), r"\s+" => "")
        @test result.content[3] isa Documenter.Documents.RawHTML
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
        @test replace(result.content[3].code, r"\s+" => "") == replace(expected, r"\s+" => "")
        @test result.content[4] isa Markdown.MD
        @test result.content[4] == Markdown.parse("""Functions:

        ```
        function g"Inline if necessary"
          input Real x;
          output Real y;
        algorithm
          y := 2.0 * x;
        end g;



        ```""")
        @test result.content[5] isa Markdown.MD
        @test result.content[5] == Markdown.parse("""
        | name | unit | value |                  label |
        | ----:| ----:| -----:| ----------------------:|
        |    r |  "V" |   0.0 |         some potential |
        |  foo |      |       | second sample variable |
        |    k |      |   2.0 |         some parameter |
        """)
    end
    withOMC("out", "res") do omc
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
                loadModel(omc, "InconsistentUnits")
                expected = MoSTError(
                    "Simulation of InconsistentUnits failed",
                    string("Warning: The following equation is INCONSISTENT due to specified unit information: sub.alias = r\n",
                    "The units of following sub-expressions need to be equal:",
                    "\n- sub-expression \"r\" has unit \"A\"",
                    "\n- sub-expression \"sub.alias\" has unit \"V\"\n")
                )
                @test_throws expected simulate(omc, "InconsistentUnits")
            end
        end
        @testset "regressionTest" begin
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
                prefixes = [commonhierarchy(e, adict) for e in eqs]
                de = [deprefix(e, p) for (e, p) in zip(eqs, prefixes)]
                @test ["x", "FunctionNames.f", "_b"] == findidentifiers(de[1])
                @test ["_b", "FunctionNames.Submodel\$sm.h", "x", "FunctionNames.Submodel\$sm.g", "x"] == findidentifiers(de[2])
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
            loadModel(omc, "DocExample")
            expected = [
                "DocExample.f" "function(x :: Real * y :: Real) => Real" "function DocExample.f\"Inline if necessary\"\n  input Real x;\n  input Real y;\n  output Real res;\nalgorithm\n  res := x ^ y + y;\nend DocExample.f;\n\n\n";
                "DocExample.g" "function(x :: Real) => Real" "function DocExample.g\"Inline if necessary\"\n  input Real x;\n  output Real y;\nalgorithm\n  y := 2.0 * x;\nend DocExample.g;\n\n\n"
            ]
            @test expected == getfunctions(omc, "DocExample")
        end
    end
end
