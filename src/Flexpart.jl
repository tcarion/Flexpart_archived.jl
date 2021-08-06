module Flexpart

using Dates
using NCDatasets
using RecipesBase
# using PyPlot

global FP_DIR = pwd()
# const FP_DIR = "/home/tcarion/rocourt_project/test1"

OPTIONS_DIR = "options"
OUTPUT_DIR = "output"
global AVAILABLE = joinpath(FP_DIR, "AVAILABLE")

global NCF_OUTPUT = ""

# include("FpOption.jl")
include("FpIO.jl")
include("FpPlots.jl")

function set_fp_dir(dir)
    global FP_DIR = dir
    global AVAILABLE = joinpath(FP_DIR, "AVAILABLE")
end

export
    Releases_ctrl,
    Release, 
    Outgrid,
    OutgridN,
    Command,
    update_available,
    write,
    write_options, area2outgrid, format, set_heights,
    find_ncf,
    all_dataset,
    mesh,
    conc,
    conc_diskarray


end
