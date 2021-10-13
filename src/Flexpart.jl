module Flexpart

using Dates
using NCDatasets
using RecipesBase
using DataStructures
using CSV
using YAML
# using Debugger
# using PyPlot

const FlexpartPath = String

mutable struct FlexpartDir
    path::FlexpartPath
    pathnames::OrderedDict{Symbol, String}
    # FlexpartDir(path::String) = is_fp_dir(path) && new(path)
    function FlexpartDir(path::String)
        pns = try
            OrderedDict(name |> Symbol => p for (name, p) in zip(PATHNAMES_VALUES, pathnames(joinpath(path, PATHNAMES))))
        catch e
            if isa(e, SystemError)
                DEFAULT_PATHNAMES
            else
                throw(e)
            end
        end
        new(path, pns)
    end
end
Base.show(io::IO, fpdir::FlexpartDir) = print(io, fpdir.path)
Base.getindex(fpdir::FlexpartDir, name::Symbol) = fpdir.pathnames[name]
function Base.setindex!(fpdir::FlexpartDir, value::String, name::Symbol)
    fpdir.pathnames[name] = value
end

const OPTIONS_DIR = "options"
const OUTPUT_DIR = "output"
const INPUT_DIR = "input"
const AVAILABLE = "AVAILABLE"
const PATHNAMES = "pathnames"
PATHNAMES_VALUES = ["options", "output", "input", "available"]

DEFAULT_PATHNAMES = OrderedDict(
    k |> Symbol => v for (k, v) in zip(PATHNAMES_VALUES, [
        OPTIONS_DIR, OUTPUT_DIR, INPUT_DIR, AVAILABLE
    ])
)

NEEDED_FILES = [OPTIONS_DIR, OUTPUT_DIR, AVAILABLE, PATHNAMES]

const DEFAULT_FP_DIR = joinpath(@__DIR__, "flexpart_dir_template")

function is_fp_dir(path::FlexpartPath)
    files = readdir(path)
    for needed in NEEDED_FILES
        needed in files || error("$path is not a flexpart directory")
    end
    true
end

function create(name::String; force=false)
    spl = splitpath(name)
    path = length(spl) == 1 ? joinpath(pwd(), name) : name
    !force && ispath(path) && error("$path already exists. force = true is required to remove existing dir")
    cp(DEFAULT_FP_DIR, path, force=force)
    FlexpartDir(path)
end

function pathnames(fpdir::FlexpartDir)
    readlines(joinpath(fpdir.path, PATHNAMES))
end

function pathnames(path::String)
    readlines(path)
end

getdir(fpdir::FlexpartDir, type::Symbol) = isempty(fpdir.pathnames) ? joinpath(fpdir.path, DEFAULT_PATH[type]) |> abspath : joinpath(fpdir.path, fpdir[type]) |> abspath

function write(fpdir::FlexpartDir)
    open(joinpath(fpdir.path, PATHNAMES), "w") do f
        for (k, v) in fpdir.pathnames
            Base.write(f, v*"\n")
        end
    end
end

include("FpInput.jl")
include("FpIO.jl")
include("FpPlots.jl")
include("Flexextract.jl")
include("readgrib.jl")

export
    FlexControl,
    FlexpartDir,
    FlexpartOptions,
    FlexpartOutput,
    FlexextractDir,
    Available,
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
    select,
    selected,
    update_available,
    write_options, area2outgrid, format,
    attrib,
    variables2d,
    deltamesh,
    areamesh,
    relloc,
    start_dt,
    end_dt,
    namelist2dict,
    write
end
