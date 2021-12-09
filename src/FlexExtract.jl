module FlexExtract

using DataStructures
using CSV
using YAML

export 
    FlexExtractDir, 
    FeControl, 
    FeSource, 
    MarsRequest,
    get,
    getpath,
    control,
    save_request,
    csvpath


const FLEX_DEFAULT_CONTROL = "CONTROL_OD.OPER.FC.eta.highres.app"
const PYTHON_RETRIEVE_SCRIPT = joinpath(@__DIR__, "pypolytope.py")
const FlexExtractPath = String

const ControlItem = Symbol
const ControlFilePath = String

const ControlFields= OrderedDict{ControlItem, Any}

struct FeControl
    path::ControlFilePath
    dict::ControlFields
end
FeControl(path::String) = FeControl(abspath(path), control2dict(path))
fields(fcontrol::FeControl) = fcontrol.dict
getpath(fcontrol::FeControl) = fcontrol.path
# Base.show(io::IO, fcontrol::FeControl) = print(io, "FeControl with fields :\n", get(fcontrol))
Base.show(io::IO, fcontrol::FeControl) = display(fields(fcontrol))
Base.getindex(fcontrol::FeControl, name::ControlItem) = fields(fcontrol)[name]
function Base.setindex!(fcontrol::FeControl, val, name::ControlItem)
    fields(fcontrol)[name] = val
end

struct FlexExtractDir
    path::FlexExtractPath
    control::FeControl
    inpath::String
    outpath::String
    function FlexExtractDir(fepath::FlexExtractPath, control::FeControl)
        fepath = abspath(fepath)
        inputdir = joinpath(fepath, "input")
        outputdir = joinpath(fepath, "output")
        (mkpath(inputdir), mkpath(outputdir))
        controlname = joinpath(fepath, basename(control.path))
        newcontrol = FeControl(controlname, fields(control))
        write(newcontrol)
        new(fepath, newcontrol, inputdir, outputdir)
    end
end
function FlexExtractDir(fepath::FlexExtractPath)
    files = readdir(fepath, join=true)
    icontrol = findfirst(x -> occursin("CONTROL", x), files .|> basename)
    isnothing(icontrol) && error("FlexExtract dir has no Control file")
    FlexExtractDir(fepath, FeControl(files[1]))
end
control(fedir::FlexExtractDir) = fedir.control
getpath(fedir::FlexExtractDir) = fedir.path
Base.show(io::IO, fedir::FlexExtractDir) = print(io, "FlexExtractDir @ ", fedir.path)

struct FeSource
    path::String
    python::String
    scripts::Dict{Symbol, <:String}
    FeSource(path::String, python::String) = new(abspath(path), python, scripts(path))
end
getpath(fesource::FeSource) = fesource.path

function Base.show(io::IO, fesource::FeSource)
    print(io, "FeSource @ ", fesource.path, "\n", "python : ", fesource.python)
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

function save_request(fedir::FlexExtractDir)
    csvp = csvpath(fedir)
    cp(csvp, joinpath(fedir.path, basename(csvp)))
end

submitcmd(fedir::FlexExtractDir, fesource::FeSource) = `$(fesource.python) $(fesource.scripts[:submit]) $(feparams(fedir))`

function submit(fedir::FlexExtractDir, fesource::FeSource)
    # params = feparams(fedir)
    # cmd = `$(fesource.python) $(fesource.scripts[:submit]) $(params)`
    cmd = submitcmd(fedir, fesource)
    println("The following command will be run : $cmd")
    Base.run(cmd)
end

function submit(f::Function, fedir::FlexExtractDir, fesource::FeSource)
    cmd = submitcmd(fedir, fesource)
    pipe = Pipe()

    @async while true
        f(pipe)
    end

    run(pipeline(cmd, stdout=pipe, stderr=pipe))
end

function retrievecmd(fesource::FeSource, request::MarsRequest, dir::String)
    filename = writeyaml(dir, request)
    cmde = [
        fesource.python,
        PYTHON_RETRIEVE_SCRIPT,
        filename,
        request[:target],
    ]
    # `$(fesource.python) $(PYTHON_RETRIEVE_SCRIPT) $(filename) $(request[:target]) $redir`
    `$cmde`
end

function retrieve_helper(fesource::FeSource, requests::MarsRequests, f = nothing)
    mktempdir() do dir
        for req in requests
            cmd = retrievecmd(fesource, req, dir)

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
retrieve_helper(fesource::FeSource, request::MarsRequest, f = nothing) = retrieve_helper(fesource, [request], f)

function retrieve(fesource::FeSource, requests)
    retrieve_helper(fesource, requests)
end

function retrieve(f::Function, fesource::FeSource, requests)
    retrieve_helper(fesource, requests, f)
end

# function retrieve(fesource::FeSource, requests::MarsRequests)
#     mktempdir() do dir
#         for req in requests
#             cmd = retrievecmd(fesource, req, dir)
#             run(cmd)
#         end
#     end
# end
# retrieve(fesource::FeSource, req::MarsRequest) = retrieve(fesource, [req])

# function retrieve(f::Function, fesource::FeSource, requests::MarsRequests)
#     mktempdir() do dir
#         for req in requests
#             cmd = retrievecmd(fesource, req, dir)
#             pipe = Pipe()

#             @async while true
#                 f(pipe)
#             end

#             run(pipeline(cmd, stdout=pipe, stderr=pipe))
#         end
#     end
# end

function preparecmd(fedir::FlexExtractDir, fesource::FeSource)
    files = readdir(fedir.inpath)
    ifile = findfirst(files) do x
        try
            split(x, '.')[4]
        catch
            false
        end
        true
    end
    ppid = split(files[ifile], '.')[4]
    `$(fesource.python) $(fesource.scripts[:prepare]) $(feparams(fedir)) $(["--ppid", ppid])`
end

function prepare(fedir::FlexExtractDir, fesource::FeSource)
    cmd = preparecmd(fedir, fesource)
    run(cmd)
end

function prepare(f::Function, fedir::FlexExtractDir, fesource::FeSource)
    cmd = preparecmd(fedir, fesource)
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
feparams(fedir::FlexExtractDir) = feparams(fedir |> control |> getpath, fedir.inpath, fedir.outpath)

function scripts(installpath::String)
    Dict(
        :run_local => joinpath(installpath, "Run", "run_local.sh"),
        :submit => joinpath(installpath, "Source", "Python", "submit.py"),
        :prepare => joinpath(installpath, "Source", "Python", "Mods", "prepare_flexpart.py"),
    )
end

csvpath(fedir::FlexExtractDir) = joinpath(fedir.inpath, "mars_requests.csv")

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
    dest = newpath == "" ? fcontrol.path : joinpath(dirname(newpath), basename(fcontrol.path))
    
    (tmppath, tmpio) = mktemp()
    
    for line in format(fcontrol) Base.write(tmpio, line*"\n") end
    
    close(tmpio)
    mv(tmppath, dest, force=true)
end

function write(fcontrol::FeControl)
    write(fcontrol, fcontrol.path)
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
set_area!(fedir::FlexExtractDir, area) = set_area!(fedir.control, area)

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
        for st in enumerate(stepdt)
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

Base.getindex(req::MarsRequest, name::Symbol) = fields(req)[name]
function Base.setindex!(req::MarsRequest, val, name::Symbol)
    fields(req)[name] = val
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
Base.iterate(req::MarsRequest, i...) = Base.iterate(req.dict, i...)
# function format_opt(opt::Int)
#     opt < 10 ? "0$(opt)" : "$(opt)"
# end

end