module Flexpart

using Dates
using NCDatasets
using RecipesBase
using DataStructures
using CSV
# using Debugger
# using PyPlot

const FlexpartPath = String

struct FlexpartDir
    path::FlexpartPath
    # FlexpartDir(path::String) = is_fp_dir(path) && new(path)
    FlexpartDir(path::String) = new(abspath(path))
end

global FP_DIR = pwd()
# const FP_DIR = "/home/tcarion/rocourt_project/test1"

const OPTIONS_DIR = "options"
const OUTPUT_DIR = "output"
const AVAILABLE = "AVAILABLE"
const PATHNAMES = "pathnames"

NEEDED_FILES = [OPTIONS_DIR, OUTPUT_DIR, AVAILABLE, PATHNAMES]

global NCF_OUTPUT = ""

function is_fp_dir(path::FlexpartPath)
    files = readdir(path)
    for needed in NEEDED_FILES
        needed in files || error("$path is not a flexpart directory")
    end
    true
end

include("FpIO.jl")
include("FpPlots.jl")
include("Flexextract.jl")

export
    FlexControl,
    FlexpartDir,
    FlexpartOptions,
    FlexpartOutput,
    FlexextractDir,
    FeSource,
    MarsRequest,
    prepare,
    set!,
    set_area!,
    set_steps!,
    ncf_files,
    retrieve,
    # Releases,
    # Releases_ctrl,
    # Release,
    # Outgrid,
    # OutgridN,
    # Command,
    update_available,
    write_options, area2outgrid, format,
    attrib,
    variables2d,
    select!,
    deltamesh,
    areamesh,
    relloc,
    start_dt,
    end_dt,
    namelist2dict
end
