module Flexpart


using GRIB
using Pkg.Artifacts
using Dates
using RecipesBase
using DataStructures: OrderedDict
using DocStringExtensions
using Rasters
using FLEXPART_jll
# using Debugger
# using PyPlot

export
    FlexpartDir,
    SimType,
    Deterministic,
    Ensemble,
    InputFiles,
    Available,
    FlexpartOption,
    AbstractOutputFile,
    OutputFiles,
    DeterministicOutput,
    EnsembleOutput,
    outputpath,
    FeControl,
    FlexExtractDir,
    MarsRequest,
    set_steps!

# @template TYPES =
#     """
#     # Summary
#     $(TYPEDEF)

#     $(DOCSTRING)

#     # Fields

#     $(TYPEDFIELDS)

#     # Constructors

#     $(METHODLIST)
#     """
const FLEXPART_EXECUTABLE = FLEXPART()
# TODO: UPDATE TO REAL ARTIFACT
const ROOT_ARTIFACT_FLEXPART_DATA = artifact"flexpart_data"
# const ROOT_ARTIFACT_FLEXPART = "test/flexpart_data"

# const OPTIONS_DIR_DEFAULT = "./options"
# const OUTPUT_DIR_DEFAULT = "./output"
# const INPUT_DIR_DEFAULT = "./input"
# const AVAILABLE_PATH_DEFAULT = "./AVAILABLE"
const DEFAULT_PATH_PATHNAMES = "./pathnames"
const PATHNAMES_KEYS = (:options, :output, :input, :available)

const DEFAULT_FP_DIR = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "default_fpdir")
# const DEFAULT_FP_DIR = joinpath(@__DIR__, "files", "flexpart_dir_template")
const FLEXIN_PATH = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "flexin")

# Paths to input files for testing purposes
const FP_TESTS_PATH = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "tests")
const FP_TESTS_DETER_INPUT = joinpath(FP_TESTS_PATH, "input", "deterministic")
const FP_TESTS_ENS_INPUT = joinpath(FP_TESTS_PATH, "input", "ensemble")

const DEFAULT_PATHNAMES = readlines(joinpath(Flexpart.DEFAULT_FP_DIR, DEFAULT_PATH_PATHNAMES))

function write end
function create end
function set! end

include("abstracts.jl")
include("flexpartdir.jl")
include("readgrib.jl")
include("utils.jl")
include("FlexpartInputs.jl")
include("FlexpartOptions.jl")
include("FlexpartOutputs.jl")
include("FlexExtract.jl")
include("run.jl")

using .FlexpartInputs
using .FlexpartOptions
using .FlexpartOutputs
using .FlexExtract

end


