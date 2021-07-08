module Flexpart

using Dates
using NetCDF
# using Plots
# using PyPlot

# const FP_DIR = pwd()
const FP_DIR = "/home/tcarion/rocourt_project/test1"

const OPTIONS_DIR = "options"
const OUTPUT_DIR = "output"
const AVAILABLE = joinpath(FP_DIR, "AVAILABLE")

global NCF_OUTPUT = ""

# include("FpOption.jl")
include("FpIO.jl")
include("FpPlots.jl")

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
    grid,
    conc,
    conc_diskarray


end
