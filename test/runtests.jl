using ModelicaScriptingTools: setupOMCSession, loadModel, simulate,
    getSimulationSettings, testmodel, closeOMCSession, withOMC, moescape,
    mounescape, MoSTError
using Test

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
        @testset "getVariableFilter" begin

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
