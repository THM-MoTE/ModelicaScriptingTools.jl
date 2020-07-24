using ModelicaScriptingTools: setupOMCSession, loadModel, simulate,
    getSimulationSettings, testmodel, closeOMCSession, withOMC, moescape,
    mounescape, MoSTError
using Test: @testset, @test, @test_nowarn, @test_throws
using OMJulia: sendExpression

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
                    "numberOfIntervals" => 50, "outputFormat" => "\"csv\"",
                    "variableFilter" => "\"sub\\\\.alias\"",
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
        end
        @testset "regressionTest" begin
        end
        loadModel(omc, "Example")
        simulate(omc, "Example", getSimulationSettings(omc, "Example"))
        cp("out/Example_res.csv", "regRefData/Example_res.csv"; force=true)
        @testset "Example" begin
            testmodel(omc, "Example", regRelTol=1e-4)
        end
    end
end
