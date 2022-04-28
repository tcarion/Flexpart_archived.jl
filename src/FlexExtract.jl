module FlexExtract

using DataStructures
using CSV
using YAML
using Dates
using FlexExtract_jll
using Pkg.Artifacts
using PyCall

import ..Flexpart: AbstractPathnames, AbstractFlexDir, write, set!
export 
    FlexExtractDir, 
    FeControl, 
    MarsRequest,
    set_area!,
    set_steps!,
    save_request,
    csvpath,
    submit,
    prepare,
    retrieve

const PATH_CALC_ETADOT = joinpath(FlexExtract_jll.artifact_dir, "bin")
const CALC_ETADOT_PARAMETER = :EXEDIR

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

const ControlItem = Symbol
const ControlFilePath = String

const ControlFields= OrderedDict{ControlItem, Any}

mutable struct FePathnames <: AbstractPathnames
    input::String
    output::String
end
FePathnames() = FePathnames("./input", "./output")
struct FeControl
    name::String
    dict::ControlFields
end
FeControl(path::String) = FeControl(basename(path), control2dict(path))
fields(fcontrol::FeControl) = fcontrol.dict
# Base.show(io::IO, fcontrol::FeControl) = print(io, "FeControl with fields :\n", get(fcontrol))
function Base.show(io::IO, mime::MIME"text/plain", fcontrol::FeControl) 
    print(io, "Control file with name $(fcontrol.name) and fields:\n")
    show(io, mime, fcontrol.dict)
end
Base.show(io::IO, fcontrol::FeControl) = print(io, fields(fcontrol))
# Base.show(io::IO, ::MIME"text/plain", fedir::FlexExtractDir) = display(fields(fcontrol))
# Base.show(io::IO, fcontrol::FeControl) = display(fields(fcontrol))
Base.getindex(fcontrol::FeControl, name::ControlItem) = fields(fcontrol)[name]
function Base.setindex!(fcontrol::FeControl, val, name::ControlItem)
    fields(fcontrol)[name] = val
end

struct FlexExtractDir <: AbstractFlexDir
    path::String
    control::FeControl
    pathnames::FePathnames
end
function FlexExtractDir(fepath::String, controlpath::String)
    fepath = abspath(fepath)
    newcontrol = FeControl(controlpath)
    FlexExtractDir(fepath, newcontrol, FePathnames("input", "output"))
end
function FlexExtractDir(fepath::String)
    files = readdir(fepath, join=true)
    icontrol = findfirst(x -> occursin("CONTROL", x), files .|> basename)
    fecontrol = isnothing(icontrol) ? FeControl(PATH_FLEXEXTRACT_DEFAULT_CONTROL) : FeControl(files[icontrol])
    FlexExtractDir(fepath, fecontrol, FePathnames())
end
FlexExtractDir(fepath::String, fcontrol::FeControl) = FlexExtractDir(fepath, fcontrol, FePathnames())
FlexExtractDir(fepath::String, fcontrolpath::String, inpath::String, outpath::String) =
    FlexExtractDir(fepath, FeControl(fcontrolpath), FePathnames(inpath, outpath))
getcontrol(fedir::FlexExtractDir) = fedir.control
getpath(fedir::FlexExtractDir) = fedir.path
controlpath(fedir::FlexExtractDir) = joinpath(abspath(fedir.path), fedir.control.name)
Base.show(io::IO, fedir::FlexExtractDir) = print(io, "FlexExtractDir @ ", fedir.path)
function Base.show(io::IO, mime::MIME"text/plain", fedir::FlexExtractDir)
    show(io, fedir)
    print(io, "\n")
    show(io, mime, fedir.control)
end
function add_exec_path(fedir::FlexExtractDir)
    push!(fedir.control.dict, CALC_ETADOT_PARAMETER => PATH_CALC_ETADOT)
    write(fedir)
end

function create(path::AbstractString)
    default_pn = FePathnames()
    mkdir(path)
    mkdir(joinpath(path, default_pn[:input]))
    mkdir(joinpath(path, default_pn[:output]))
    fn = cp(PATH_FLEXEXTRACT_DEFAULT_CONTROL, joinpath(path, FLEX_DEFAULT_CONTROL))
    chmod(fn, 0o664)
    FlexExtractDir(path)
end

struct MarsRequest
    dict::OrderedDict{Symbol, Any}
    request_number::Int64
end

const MarsRequests = Array{MarsRequest}

function MarsRequest(row::CSV.Row)
    d = Dict{Symbol, Any}()
    for name in propertynames(row)
        value = row[name]
        valuestr = row[name] |> string |> strip
        valuestr |> isempty && continue
        value = valuestr[1]=='/' ? "\"" * valuestr * "\""  : valuestr

        name = name == :marsclass ? :class : name
        push!(d, name => value)
    end
    MarsRequest(d, parse(Int64, pop!(d, :request_number)))
end
MarsRequest(csv::CSV.File)::MarsRequests = [MarsRequest(row) for row in csv]
MarsRequest(csvpath::String)::MarsRequests = MarsRequest(CSV.File(csvpath, normalizenames= true))
MarsRequest(dict::AbstractDict) = MarsRequest(convert(OrderedDict, dict), 1)
fields(req::MarsRequest) = req.dict

Base.getindex(req::MarsRequest, name::Symbol) = fields(req)[name]
function Base.setindex!(req::MarsRequest, val, name::Symbol)
    fields(req)[name] = val
end
Base.iterate(req::MarsRequest, i...) = Base.iterate(req.dict, i...)
Base.show(io::IO, mime::MIME"text/plain", req::MarsRequest) = show(io, mime, req.dict)


function save_request(fedir::FlexExtractDir)
    csvp = csvpath(fedir)
    cp(csvp, joinpath(fedir.path, basename(csvp)))
end

submitcmd(fedir::FlexExtractDir) = `$(PYTHON_EXECUTABLE) $(PATH_PYTHON_SCRIPTS[:submit]) $(feparams(fedir))`

function submit(fedir::FlexExtractDir)
    # params = feparams(fedir)
    # cmd = `$(fesource.python) $(fesource.scripts[:submit]) $(params)`
    cmd = submitcmd(fedir)
    println("The following command will be run : $cmd")
    Base.run(cmd)
end

function submit(f::Function, fedir::FlexExtractDir)
    cmd = submitcmd(fedir)
    println("The following command will be run : $cmd")
    pipe = Pipe()

    @async while true
        f(pipe)
    end

    run(pipeline(cmd, stdout=pipe, stderr=pipe))
end

function retrievecmd(request::MarsRequest, dir::String; withmars = false)
    filename = !withmars ? writeyaml(dir, request) : writemars(dir, request)
    if withmars
        args = [
            MARS_RETRIEVE_SCRIPT,
            filename,
        ]
    else
        args = [
            POLYTOPE_RETRIEVE_SCRIPT,
            filename,
            request[:target],
        ]
    end
    `$(PYTHON_EXECUTABLE) $args`
end

function _retrieve_helper(requests::MarsRequests, f = nothing; withmars = false)
    mktempdir() do dir
        for req in requests
            cmd = retrievecmd(req, dir; withmars = withmars)

            if isnothing(f)
                run(cmd)
            else
                pipe = Pipe()

                @async while true
                    f(pipe)
                end

                run(pipeline(cmd, stdout=pipe, stderr=pipe))
            end
        end
    end
end
_retrieve_helper(request::MarsRequest, f = nothing; withmars = false) = _retrieve_helper([request], f; withmars = withmars)

function retrieve(requests; withmars = false)
    _retrieve_helper(requests; withmars = withmars)
end

function retrieve(f::Function, requests; withmars = false)
    _retrieve_helper(requests, f; withmars = withmars)
end

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
    cmd = preparecmd(fedir)
    run(cmd)
end

function prepare(f::Function, fedir::FlexExtractDir)
    cmd = preparecmd(fedir)
    pipe = Pipe()

    @async while true
        f(pipe)
    end

    run(pipeline(cmd, stdout=pipe, stderr=pipe))
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
feparams(fedir::FlexExtractDir) = feparams(controlpath(fedir), fedir[:input], fedir[:output])

csvpath(fedir::FlexExtractDir) = joinpath(fedir[:input], "mars_requests.csv")

function control2dict(filepath)
    d = ControlFields()
    f = open(filepath, "r")
    for line in eachline(f)
        m = match(r"^(.*?)\s(.*)", line)
        push!(d, m.captures[1] |> Symbol => m.captures[2])
    end
    close(f)
    return d
end


function write(fcontrol::FeControl, newpath::String)
    # dest = newpath == "" ? fcontrol.path : joinpath(dirname(newpath), basename(fcontrol.path))
    dest = joinpath(newpath, fcontrol.name)
    (tmppath, tmpio) = mktemp()
    
    for line in format(fcontrol) Base.write(tmpio, line*"\n") end
    
    close(tmpio)
    mv(tmppath, dest, force=true)
end

# function write(fcontrol::FeControl)
#     write(fcontrol, fcontrol.path)
# end

function write(fedir::FlexExtractDir)
    write(fedir.control, fedir.path)
end

function Base.write(io::IOStream, req::MarsRequest)
    for line in format(req) write(io, line*"\n") end
end

function write(dest::String, req::MarsRequest)
    (tmppath, tmpio) = mktemp()

    write(tmpio, req)

    close(tmpio)
    mv(tmppath, joinpath(dest, "mars_req_$(req.request_number)"), force=true)
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
        for (k, v) in req.dict
            Base.write(io, "$k $v\n")
        end
    end
    filename
end

function format(fcontrol::FeControl)::Vector{String}
    str = []
    for (k, v) in fields(fcontrol)
        key = uppercase(String(k))
        # val = v |> typeof <: Vector ? join(field, ",") : field
        push!(str, "$key $v")
    end
    str
end

function format(req::MarsRequest)
    str = ["retrieve,"]
    for (name, value) in req
        line = "$name=$value,"
        push!(str, line)
    end
    str[end] = strip(str[end], ',')
    str
end

function set_area!(fcontrol::FeControl, area; grid = nothing)
    if !isnothing(grid)
        alons = -180.0:grid:180.0 |> collect
        outerlons = outer_vals(alons, (area[2], area[4]))
        alats = -90.0:grid:90.0 |> collect
        outerlats = outer_vals(alats, (area[3], area[1]))
        area = [outerlats[2], outerlons[1], outerlats[1], outerlons[2]]
    end
    new = Dict(
        :LOWER => area[3] isa String || string(area[3]), 
        :UPPER => area[1] isa String || string(area[1]), 
        :LEFT => area[2] isa String || string(area[2]), 
        :RIGHT => area[4] isa String || string(area[4]),
    )
    set!(fcontrol, new)
end
set_area!(fedir::FlexExtractDir, area; grid = nothing) = set_area!(fedir.control, area; grid = grid)

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
    set!(fcontrol, newd)
end
set_steps!(fedir::FlexExtractDir, startdate, enddate, timestep) = set_steps!(fedir.control, startdate, enddate, timestep)

function set!(fcontrol::FeControl, newv::Dict{Symbol, <:Any})
    merge!(fields(fcontrol), newv)
end

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

end