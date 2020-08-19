using ModelicaScriptingTools: setupOMCSession, loadModel, simulate,
    getSimulationSettings, testmodel, closeOMCSession, withOMC, moescape,
    mounescape, MoSTError, regressionTest, getDocAnnotation, getcode,
    getequations
using Test: @testset, @test, @test_nowarn, @test_throws
using OMJulia: sendExpression
using DataFrames: Not, select!
using CSV

if !isdir("out")
    mkdir("out")
end

if !isdir("regRefData")
    mkdir("regRefData")
end

@testset "MoST" begin
    @testset "moescape" begin
        @test raw"\\\"test\t\\data\?\\\"" == moescape("\"test\t\\data?\"")
    end
    @testset "mounescape" begin
        @test "\"test\t\\data?\"" == mounescape(raw"\\\"test\t\\data\?\\\"")
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
                data = CSV.read(csvfile)
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
        @testset "getvariables" begin
            loadModel(omc, "Example")
            expected = []
            @test expected == getvariables(omc, "Example")
        end
    end
end
