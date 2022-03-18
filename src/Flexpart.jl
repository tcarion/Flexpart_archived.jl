module Flexpart

using Pkg.Artifacts
using Dates
using RecipesBase
using DataStructures: OrderedDict
using DocStringExtensions
using Rasters
# using Debugger
# using PyPlot

export
    FlexpartDir,
    FpSource,
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
    FeSource,
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
const DEFAULT_BIN = "FLEXPART"
const ROOT_ARTIFACT_FLEXPART = artifact"flexpart"

# const OPTIONS_DIR_DEFAULT = "./options"
# const OUTPUT_DIR_DEFAULT = "./output"
# const INPUT_DIR_DEFAULT = "./input"
# const AVAILABLE_PATH_DEFAULT = "./AVAILABLE"
const DEFAULT_PATH_PATHNAMES = "./pathnames"
const PATHNAMES_KEYS = (:options, :output, :input, :available)

const DEFAULT_FP_DIR = joinpath(ROOT_ARTIFACT_FLEXPART, "flexpart")
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


