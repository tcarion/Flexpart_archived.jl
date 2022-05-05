module FlexExtract

using DataStructures
using CSV
using YAML
using Dates
using FlexExtract_jll
using Pkg.Artifacts
using PyCall

import ..Flexpart: AbstractPathnames, AbstractFlexDir, write, writelines, outer_vals, getpathnames
export 
    FlexExtractDir,
    FeControl, 
    MarsRequest,
    set_area!,
    set_area,
    set_steps!,
    save_request,
    csvpath,
    submit,
    prepare,
    retrieve

const PATH_CALC_ETADOT = joinpath(FlexExtract_jll.artifact_dir, "bin")
const CALC_ETADOT_PARAMETER = :EXEDIR
const CMD_CALC_ETADOT = FlexExtract_jll.calc_etadot()

const ROOT_ARTIFACT_FLEXEXTRACT = artifact"flex_extract"
const PATH_FLEXEXTRACT = joinpath(ROOT_ARTIFACT_FLEXEXTRACT, "flex_extract_v7.1.2")

const FLEX_DEFAULT_CONTROL = "CONTROL_OD.OPER.FC.eta.highres"
const PATH_FLEXEXTRACT_CONTROL_DIR = joinpath(PATH_FLEXEXTRACT, "Run", "Control")
const PATH_FLEXEXTRACT_DEFAULT_CONTROL = joinpath(PATH_FLEXEXTRACT_CONTROL_DIR, FLEX_DEFAULT_CONTROL)

const POLYTOPE_RETRIEVE_SCRIPT = joinpath(@__DIR__, "pypolytope.py")
const MARS_RETRIEVE_SCRIPT = joinpath(@__DIR__, "pymars.py")

const PATH_PYTHON_SCRIPTS = Dict(
    :run_local => joinpath(PATH_FLEXEXTRACT, "Run", "run_local.sh"),
    :submit => joinpath(PATH_FLEXEXTRACT, "Source", "Python", "submit.py"),
    :prepare => joinpath(PATH_FLEXEXTRACT, "Source", "Python", "Mods", "prepare_flexpart.py"),
)

const PYTHON_EXECUTABLE = PyCall.python


const ecmwfapi = PyNULL()
const ecmwf_public_server = PyNULL()
const ecmwf_mars_server = PyNULL()

const polytopeapi = PyNULL()
const polytope_client = PyNULL()

function __init__()
    py"""
    import ssl
    ssl._create_default_https_context = ssl._create_unverified_context
    """
    copy!(ecmwfapi, pyimport_conda("ecmwfapi", "ecmwfapi"))
    copy!(ecmwf_public_server, ecmwfapi.ECMWFDataServer())
    copy!(ecmwf_mars_server, ecmwfapi.ECMWFService("mars"))

    # Try to import the optional polytope-client package
    try
        copy!(polytopeapi, pyimport_conda("polytope.api", "polytope"))
        copy!(polytope_client, polytopeapi.Client(address = "polytope.ecmwf.int"))
        try
            # Would be better to simply redirect stdout to devnull, but it doesn't work
            tmp_cli = polytopeapi.Client(address = "polytope.ecmwf.int", quiet = true)
            # redirect_stdout(devnull) do 
            tmp_cli.list_collections()
            # end
        catch e
            if e isa PyCall.PyError
                @warn "It seems you don't have credentials for the polytope api."
            else
                throw(e)
            end
        end
    catch

    end


end
# const ControlItem = Symbol
# const ControlFilePath = String

# const ControlFields= OrderedDict{ControlItem, Any}

abstract type WrappedOrderedDict{K,V} <: AbstractDict{K,V} end

mutable struct FePathnames <: AbstractPathnames
    input::AbstractString
    output::AbstractString
    controlfile::AbstractString
end
FePathnames() = FePathnames("./input", "./output", PATH_FLEXEXTRACT_DEFAULT_CONTROL)
FePathnames(controlpath::AbstractString) = FePathnames("./input", "./output", controlpath)

struct FlexExtractDir <: AbstractFlexDir
    path::AbstractString
    pathnames::FePathnames
end
function FlexExtractDir(fepath::AbstractString, controlpath::AbstractString)
    fepath = abspath(fepath)
    FlexExtractDir(abspath(fepath), FePathnames("input", "output", abspath(controlpath)))
end
# function FlexExtractDir(fepath::AbstractString)
#     files = readdir(fepath, join=true)
#     icontrol = findfirst(x -> occursin("CONTROL", x), files .|> basename)
#     fecontrol = isnothing(icontrol) ? FeControl(PATH_FLEXEXTRACT_DEFAULT_CONTROL) : FeControl(files[icontrol])
#     FlexExtractDir(fepath, FePathnames())
# end
# FlexExtractDir(fepath::AbstractString, fcontrol::FeControl) = FlexExtractDir(fepath, fcontrol, FePathnames())
FlexExtractDir(fepath::AbstractString, fcontrolpath::AbstractString, inpath::AbstractString, outpath::AbstractString) =
    FlexExtractDir(fepath, FePathnames(inpath, outpath, fcontrolpath))
FlexExtractDir() = create(mktempdir())
getpathnames(fedir::FlexExtractDir) = fedir.pathnames
# getcontrol(fedir::FlexExtractDir) = fedir.control
# getpath(fedir::FlexExtractDir) = fedir.path
# controlpath(fedir::FlexExtractDir) = joinpath(abspath(fedir.path), fedir.control.name)
# Base.show(io::IO, fedir::FlexExtractDir) = show(io, "FlexExtractDir @ ", fedir.path)
function Base.show(io::IO, mime::MIME"text/plain", fedir::FlexExtractDir)
    println(io, "FlexExtractDir @ ", fedir.path)
    show(io, mime, fedir.pathnames)
    # print(io, "\n")
    # print(io, "with Control file:")
    # show(io, mime, FeControl(fedir))
end

function create(path::AbstractString)
    mkdir(path)
    default_pn = FePathnames()
    mkdir(joinpath(path, default_pn[:input]))
    mkdir(joinpath(path, default_pn[:output]))
    fn = cp(default_pn[:controlfile], joinpath(path, basename(default_pn[:controlfile])))
    chmod(fn, 0o664)
    FlexExtractDir(path, fn)
end

struct FeControl{K<:Symbol, V} <: WrappedOrderedDict{K, V}
    path::AbstractString
    dict:: OrderedDict{K, V}
end
FeControl(path::String) = FeControl(abspath(path), control2dict(path))
FeControl(fedir::FlexExtractDir) = FeControl(fedir[:controlfile])
parent(fcontrol::FeControl) = fcontrol.dict

function add_exec_path(fcontrol::FeControl)
    push!(fcontrol, CALC_ETADOT_PARAMETER => PATH_CALC_ETADOT)
    write(fcontrol)
end
add_exec_path(fedir::FlexExtractDir) = add_exec_path(FeControl(fedir))

struct MarsRequest{K<:Symbol, V} <: WrappedOrderedDict{K, V}
    dict::OrderedDict{K, V}
    request_number::Int64
end

const MarsRequests = Vector{<:MarsRequest}

function MarsRequest(row::CSV.Row)
    d = OrderedDict{Symbol, Any}()
    for name in propertynames(row)
        value = row[name]
        valuestr = row[name] |> string |> strip
        valuestr |> isempty && continue
        valuestr = valuestr[1]=='/' ? "\"" * valuestr * "\""  : valuestr
        name = name == :marsclass ? :class : name
        push!(d, name => valuestr)
    end
    MarsRequest(d, parse(Int64, pop!(d, :request_number)))
end
MarsRequest(csv::CSV.File)::MarsRequests = [MarsRequest(row) for row in csv]
MarsRequest(csvpath::String)::MarsRequests = MarsRequest(CSV.File(csvpath, normalizenames= true))
MarsRequest(dict::AbstractDict) = MarsRequest(convert(OrderedDict, dict), 1)
parent(req::MarsRequest) = req.dict

Base.show(io::IO, mime::MIME"text/plain", fcontrol::WrappedOrderedDict) = show(io, mime, parent(fcontrol))
Base.show(io::IO, fcontrol::WrappedOrderedDict) = show(io, parent(fcontrol))
Base.length(fcontrol::WrappedOrderedDict) = length(parent(fcontrol))
Base.getindex(fcontrol::WrappedOrderedDict, name) = getindex(parent(fcontrol), name)
Base.setindex!(fcontrol::WrappedOrderedDict, val, name) = setindex!(parent(fcontrol), val, name)
Base.iterate(fcontrol::WrappedOrderedDict) = iterate(parent(fcontrol))
Base.iterate(fcontrol::WrappedOrderedDict, state) = iterate(parent(fcontrol), state)

function save_request(fedir::FlexExtractDir)
    csvp = csvpath(fedir)
    cp(csvp, joinpath(fedir.path, basename(csvp)))
end

adapt_env(cmd) = addenv(cmd, CMD_CALC_ETADOT.env)
function adapt_and_run(cmd)
    cmd_with_new_env = adapt_env(cmd)
    Base.run(cmd_with_new_env)
end

# function modify_control(fedir::FlexExtractDir)
#     dir = mktempdir()
#     newcontrol = cp(fedir[:controlfile], joinpath(dir, basename(fedir[:controlfile])))
#     newfedir = FlexExtractDir(fedir.path, FePathnames(fedir[:input], fedir[:output], newcontrol))
#     add_exec_path(newfedir)
#     newfedir
# end

submitcmd(fedir::FlexExtractDir) = `$(PYTHON_EXECUTABLE) $(PATH_PYTHON_SCRIPTS[:submit]) $(feparams(fedir))`

function submit(fedir::FlexExtractDir)
    # params = feparams(fedir)
    # cmd = `$(fesource.python) $(fesource.scripts[:submit]) $(params)`
    add_exec_path(fedir)
    cmd = submitcmd(fedir)
    adapt_and_run(cmd)
end

function submit(f::Function, fedir::FlexExtractDir)
    add_exec_path(fedir)
    cmd = submitcmd(fedir)
    pipe = Pipe()

    @async while true
        f(pipe)
    end

    cmd = pipeline(cmd, stdout=pipe, stderr=pipe)
    adapt_and_run(cmd)
end

function runmars(req::MarsRequest)
    if occursin("None", req[:dataset])
        ecmwf_mars_server.execute(parent(req), _format_target(req[:target]))
    else
        ecmwf_public_server.retrieve(parent(req))
    end
end

function runpolytope(req::MarsRequest)
    polytope_client.retrieve("ecmwf-mars", parent(req), _format_target(req[:target]))
end

# function retrievecmd(request::MarsRequest, dir::String; polytope = false)
#     filename = !polytope ? writeyaml(dir, request) : writemars(dir, request)
#     if polytope
#         args = [
#             MARS_RETRIEVE_SCRIPT,
#             filename,
#         ]
#     else
#         args = [
#             POLYTOPE_RETRIEVE_SCRIPT,
#             filename,
#             request[:target],
#         ]
#     end
#     `$(PYTHON_EXECUTABLE) $args`
# end

# function _retrieve_helper(requests::MarsRequests, f = nothing; polytope = false)
#     mktempdir() do dir
#         for req in requests
#             cmd = retrievecmd(req, dir; polytope = polytope)

#             if !isnothing(f)
#                 pipe = Pipe()

#                 @async while true
#                     f(pipe)
#                 end
#                 cmd = pipeline(cmd, stdout=pipe, stderr=pipe)
#             end
#             adapt_and_run(cmd)
#         end
#     end
# end
function _retrieve_helper(requests::MarsRequests; polytope = false)

end
# _retrieve_helper(request::MarsRequest, f = nothing; polytope = false) = _retrieve_helper([request], f; polytope = polytope)

function retrieve(request::MarsRequest; polytope = false)
    !polytope ? runmars(request) : runpolytope(request)
end

function retrieve(requests::MarsRequests; polytope = false)
    for req in requests
        retrieve(req, polytope = polytope)
    end
end

# function retrieve(f::Function, requests; polytope = false)
#     _retrieve_helper(requests, f; polytope = polytope)
# end

function preparecmd(fedir::FlexExtractDir)
    files = readdir(fedir[:input])
    ifile = findfirst(files) do x
        try
            split(x, '.')[4]
        catch
            false
        end
        true
    end
    ppid = split(files[ifile], '.')[4]
    `$(PYTHON_EXECUTABLE) $(PATH_PYTHON_SCRIPTS[:prepare]) $(feparams(fedir)) $(["--ppid", ppid])`
end

function prepare(fedir::FlexExtractDir)
    add_exec_path(fedir)
    cmd = preparecmd(fedir)
    adapt_and_run(cmd)
end

function prepare(f::Function, fedir::FlexExtractDir)
    add_exec_path(fedir)
    cmd = preparecmd(fedir)
    pipe = Pipe()

    @async while true
        f(pipe)
    end

    adapt_and_run(pipeline(cmd, stdout=pipe, stderr=pipe))
end

function feparams(control::String, input::String, output::String)
    formated_exec = Dict("inputdir" => input, "outputdir" => output, "controlfile" => control)
    params = []
    for (k, v) in formated_exec 
        push!(params, "--$k") 
        push!(params, v)
    end
    params
end
feparams(fedir::FlexExtractDir) = feparams(fedir[:controlfile], fedir[:input], fedir[:output])

csvpath(fedir::FlexExtractDir) = joinpath(fedir[:input], "mars_requests.csv")

function control2dict(filepath) :: OrderedDict{Symbol, Any}
    open(filepath, "r") do f
        OrderedDict{Symbol, Any}(
            map(eachline(f)) do line
                m = match(r"(.*?)\s(.*)", line)
                m.captures[1] |> Symbol => m.captures[2]
            end
        )
    end
end


# function write(fcontrol::FeControl, newpath::String)
#     # dest = newpath == "" ? fcontrol.path : joinpath(dirname(newpath), basename(fcontrol.path))
#     dest = joinpath(newpath, fcontrol.name)
#     (tmppath, tmpio) = mktemp()
    
#     for line in format(fcontrol) Base.write(tmpio, line*"\n") end
    
#     close(tmpio)
#     mv(tmppath, dest, force=true)
# end

function write(fcontrol::FeControl)
    # dest = newpath == "" ? fcontrol.path : joinpath(dirname(newpath), basename(fcontrol.path))
    dest = fcontrol.path
    writelines(dest, format(fcontrol))
    # (tmppath, tmpio) = mktemp()
    
    # for line in format(fcontrol) Base.write(tmpio, line*"\n") end
    
    # close(tmpio)
    # mv(tmppath, dest, force=true)
end

# function write(fcontrol::FeControl)
#     write(fcontrol, fcontrol.path)
# end

# write(fedir::FlexExtractDir) = write(FeControl(fedir))

function write(dest::String, req::MarsRequest)
    path = joinpath(dest, "mars_req_$(req.request_number)")
    writelines(path, format(req))
end

function write(dest::String, reqs::MarsRequests)
    for req in reqs
        write(dest, req)
    end
end

function writeyaml(dest::String, req::MarsRequest) 
    filename = joinpath(dest, "mars_req_$(req.request_number)")
    YAML.write_file(filename, req.dict)
    filename
end
function writemars(dest::String, req::MarsRequest)
    filename = joinpath(dest, "mars_req_$(req.request_number)")
    open(filename, "w") do io
        for (k, v) in req
            Base.write(io, "$k $v\n")
        end
    end
    filename
end

function format(fcontrol::FeControl)::Vector{String}
    ["$(uppercase(String(k))) $v" for (k,v) in fcontrol]
end

function format(req::MarsRequest)::Vector{String}
    str = ["retrieve,"]
    for (name, value) in req
        line = "$name=$value,"
        push!(str, line)
    end
    str[end] = strip(str[end], ',')
    str
end

function set_area!(fcontrol::FeControl, area; grid = nothing)
    new = Dict()
    if !isnothing(grid)
        alons = -180.0:grid:180.0 |> collect
        outerlons = outer_vals(alons, (area[2], area[4]))
        alats = -90.0:grid:90.0 |> collect
        outerlats = outer_vals(alats, (area[3], area[1]))
        area = [outerlats[2], outerlons[1], outerlats[1], outerlons[2]]
        push!(new, :GRID => grid)
    end
    new = push!(new,
        :LOWER => area[3],
        :UPPER => area[1],
        :LEFT => area[2],
        :RIGHT => area[4],
    )
    merge!(fcontrol, new)
end
function set_area(fedir::FlexExtractDir, area; grid = nothing)::FeControl
    fcontrol = FeControl(fedir)
    set_area!(fcontrol , area; grid = grid)
    fcontrol
end

function set_steps!(fcontrol::FeControl, startdate, enddate, timestep)
    stepdt = startdate:Dates.Hour(timestep):(enddate - Dates.Hour(1))
    type_ctrl = []
    time_ctrl = []
    step_ctrl = []

    format_opt = opt -> opt < 10 ? "0$(opt)" : "$(opt)"
    if occursin("EA", fcontrol[:CLASS])
        for st in stepdt
            push!(time_ctrl, Dates.Hour(st).value % 24 |> format_opt)
            push!(type_ctrl, "AN")
            push!(step_ctrl, 0 |> format_opt)
        end
    else
        for st in stepdt
            push!(time_ctrl, div(Dates.Hour(st).value, 12) * 12 |> format_opt)
            step = Dates.Hour(st).value .% 12
            step == 0 ? push!(type_ctrl, "AN") : push!(type_ctrl, "FC")
            push!(step_ctrl, step |> format_opt)
        end
    end

    newd = Dict(
        :START_DATE => Dates.format(startdate, "yyyymmdd"), 
        :TYPE => join(type_ctrl, " "),
        :TIME => join(time_ctrl, " "), 
        :STEP => join(step_ctrl, " "), 
        :DTIME => timestep isa String || string(timestep),
    )
    merge!(fcontrol, newd)
end
set_steps!(fedir::FlexExtractDir, startdate, enddate, timestep) = set_steps!(fedir.control, startdate, enddate, timestep)

# function Base.merge!(fcontrol::FeControl, newv::Dict{Symbol, <:Any})
#     merge!(parent(fcontrol), newv)
# end

# function Base.getproperty(req::MarsRequest, name::Symbol) 
#     if name !== :dict
#         get(req)[name]
#     else
#         getfield(req, name)
#     end
# end
# function Base.setproperty!(req::MarsRequest, val, name::Symbol)
#     get(req)[name] = val
# end
# function format_opt(opt::Int)
#     opt < 10 ? "0$(opt)" : "$(opt)"
# end

_format_target(target) = replace(target, "\"" => "") 
end