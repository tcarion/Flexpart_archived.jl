using Flexpart
using Flexpart.FlexpartInputs: InputFiles, DeterministicInput, EnsembleInput, format
using Test, Dates

infilesdet = InputFiles{Deterministic}("../test/fp_dir_test/input")
infilesens = InputFiles{Ensemble}()
detinput = DeterministicInput("../test/fp_dir_test/input/EH20010100")
ensinput = EnsembleInput(Dates.now(), "filename", 1, "/path/to/file")

@testset "InputFiles length and filter" begin
    @test infilesdet[1] isa DeterministicInput
    @test eltype(infilesens) isa SimType
    @test length(infilesdet) == 3
    @test length(infilesens) == 0
    @test filter(x -> x.filename == "EH20010100", infilesdet)[1] isa DeterministicInput
end

av_from_file = Available{Deterministic}("../test/fp_dir_test/AVAILABLE", "../test/fp_dir_test/input", fromdir = false)
av_from_dir = Available{Deterministic}("../test/fp_dir_test/AVAILABLE", "../test/fp_dir_test/input", fromdir = true)

formated = format(av_from_dir)

Flexpart.write(av_from_dir)

@testset "Available length and filter" begin
    @test length(av) == 3
    @test filter(x -> Dates.Hour(x.time).value == 0, av_from_dir)[1] == DeterministicInput(DateTime("2020-01-01T00:00:00"), "EH20010100", "../test/fp_dir_test/input")
end