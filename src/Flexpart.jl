module Flexpart

using Dates
using RecipesBase
using DataStructures: OrderedDict
# using Debugger
# using PyPlot

export
    FlexpartDir,
    SimType,
    Deterministic,
    Ensemble,
    pathnames


@enum SimType Deterministic Ensemble

const FlexpartPath = String
struct FlexpartDir{SimType} 
    path::FlexpartPath
    pathnames::OrderedDict{Symbol, String}
    # FlexpartDir(path::String) = is_fp_dir(path) && new(path)
end
FlexpartDir(path::String) = FlexpartDir{Deterministic}(path, _fpdir_helper(path))
FlexpartDir{Deterministic}(path::String) = FlexpartDir{Deterministic}(path, _fpdir_helper(path))
FlexpartDir{Ensemble}(path::String) = FlexpartDir{Ensemble}(path, _fpdir_helper(path))

getpathnames(fpdir::FlexpartDir) = fpdir.pathnames

function _fpdir_helper(path::String)
    try
        OrderedDict(name |> Symbol => p for (name, p) in zip(PATHNAMES_VALUES, pathnames(joinpath(path, PATHNAMES))))
    catch e
        if isa(e, SystemError)
            DEFAULT_PATHNAMES
        else
            throw(e)
        end
    end
end
# pathnames(fpdir::FlexpartDir) = fpdir.pathnames
function Base.show(io::IO, fpdir::FlexpartDir) 
    println(io,"$(typeof(fpdir)) @ $(fpdir.path)")
    println(io, "pathnames:")
    # println(getpathnames(fpdir))
    for p in getpathnames(fpdir)
        println(io, "\t", p)
    end
    return
end
Base.getindex(fpdir::FlexpartDir, name::Symbol) = getpathnames(fpdir)[name]
function Base.setindex!(fpdir::FlexpartDir, value::String, name::Symbol)
    getpathnames(fpdir)[name] = value
end

const OPTIONS_DIR = "options"
const OUTPUT_DIR = "output"
const INPUT_DIR = "input"
const AVAILABLE = "AVAILABLE"
const PATHNAMES = "pathnames"
const PATHNAMES_VALUES = ("options", "output", "input", "available")

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


include("readgrib.jl")
include("utils.jl")
include("FpInputs.jl")
include("FpOptions.jl")
include("FpOutput.jl")
include("FlexExtract.jl")
include("Ensembles.jl")
end


