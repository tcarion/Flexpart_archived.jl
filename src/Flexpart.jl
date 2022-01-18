module Flexpart

using Dates
using RecipesBase
using DataStructures: OrderedDict
using DocStringExtensions
# using Debugger
# using PyPlot

export
    FlexpartDir,
    FpSource,
    SimType,
    Deterministic,
    Ensemble,
    FlexpartInput,
    Available,
    FlexpartOption,
    FlexpartOutput,
    DeterministicOutput,
    EnsembleOutput,
    outputpath

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

const OPTIONS_DIR_DEFAULT = "./options"
const OUTPUT_DIR_DEFAULT = "./output"
const INPUT_DIR_DEFAULT = "./input"
const AVAILABLE_PATH_DEFAULT = "./AVAILABLE"
const PATHNAMES_PATH_DEFAULT = "./pathnames"
const PATHNAMES_KEYS = (:options, :output, :input, :available)
const DEFAULT_PATHNAMES = (OPTIONS_DIR_DEFAULT, OUTPUT_DIR_DEFAULT, INPUT_DIR_DEFAULT, AVAILABLE_PATH_DEFAULT)

const DEFAULT_FP_DIR = joinpath(@__DIR__, "files", "flexpart_dir_template")

function write end

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


end


