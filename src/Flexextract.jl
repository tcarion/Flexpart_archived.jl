const FLEX_DEFAULT_CONTROL = "CONTROL_OD.OPER.FC.eta.highres.app"

const FlexextractPath = String

const ControlItem = Symbol
const ControlFilePath = String

const FeControl= OrderedDict{ControlItem, Any}
struct FlexControl
    path::ControlFilePath
    control::FeControl
end
FlexControl(path::String) = FlexControl(abspath(path), control2dict(path))

struct FlexextractDir
    path::FlexextractPath
    control::FlexControl
    inpath::String
    outpath::String
    controlpath::String
    function FlexextractDir(fepath::FlexextractPath, control::FlexControl)
        fepath = abspath(fepath)
        inputdir = joinpath(fepath, "input")
        outputdir = joinpath(fepath, "output")
        (mkpath(inputdir), mkpath(outputdir))
        controlname = joinpath(fepath, basename(control.path))
        newcontrol = FlexControl(controlname, control.control)
        Base.write(newcontrol)
        new(fepath, newcontrol, inputdir, outputdir, controlname)
    end
end
Base.show(io::IO, fedir::FlexextractDir) = print(io, "FlexextractDir @ ", fedir.path)

struct FeSource
    path::String
    python::String
    scripts::Dict{Symbol, <:String}
    FeSource(path::String, python::String) = new(abspath(path), python, scripts(path))
end

function Base.show(io::IO, fesource::FeSource)
    print(io, "FeSource @ ", fesource.path, "\n", "python : ", fesource.python)
end
struct MarsRequest
    dict::OrderedDict{Symbol, Any}
end

const MarsRequests = Array{MarsRequest}

function MarsRequest(row::CSV.Row)
    d = Dict{Symbol, Any}()
    for name in propertynames(row)
        value = row[name]
        valuestr = row[name] |> string |> strip
        valuestr |> isempty && continue
        value = valuestr[1]=='/' ? "\"" * valuestr * "\""  : value

        name = name == :marsclass ? :class : name
        push!(d, name => value)
    end
    d
    MarsRequest(d)
end
MarsRequest(csv::CSV.File)::MarsRequests = [MarsRequest(row) for row in csv]
MarsRequest(csvpath::String)::MarsRequests = MarsRequest(CSV.File(csvpath, normalizenames= true))


runcmd(fedir::FlexextractDir, fesource::FeSource) = `$(fesource.python) $(fesource.scripts[:submit]) $(feparams(fedir))`

function Base.run(fedir::FlexextractDir, fesource::FeSource; async=false)
    # params = feparams(fedir)
    # cmd = `$(fesource.python) $(fesource.scripts[:submit]) $(params)`
    cmd = runcmd(fedir, fesource)
    if async
        open(joinpath(fedir.path, "fe_run.log"), "w") do f
            Base.run(pipeline(cmd, f))
        end
    else
        Base.run(cmd)
    end
end

function retrieve(binpath::String, req::MarsRequest)
    
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
feparams(fedir::FlexextractDir) = feparams(fedir.controlpath, fedir.inpath, fedir.outpath)

function scripts(installpath::String)
    Dict(
        :run_local => joinpath(installpath, "Run", "run_local.sh"),
        :submit => joinpath(installpath, "Source", "Python", "submit.py"),
        :prepare => joinpath(installpath, "Source", "Python", "Mods", "prepare_flexpart.py"),
    )
end

function control2dict(filepath)
    d = FeControl()
    f = open(filepath, "r")
    for line in eachline(f)
        m = match(r"^(.*?)\s(.*)", line)
        push!(d, m.captures[1] |> Symbol => m.captures[2])
    end
    close(f)
    return d
end


function write(fcontrol::FlexControl, newpath::String)
    dest = newpath == "" ? fcontrol.path : joinpath(dirname(newpath), basename(fcontrol.path))
    
    (tmppath, tmpio) = mktemp()
    
    for line in format(fcontrol) Base.write(tmpio, line*"\n") end
    
    close(tmpio)
    mv(tmppath, dest, force=true)
end

function Base.write(fcontrol::FlexControl)
    write(fcontrol, fcontrol.path)
end

function Base.write(io::IOStream, req::MarsRequest)
    for line in format(req) Base.write(io, line*"\n") end
end

function Base.write(dest::String, req::MarsRequest)
    (tmppath, tmpio) = mktemp()

    Base.write(tmpio, req)

    close(tmpio)
    mv(tmppath, joinpath(dest, "mars_req_$(req[:request_number])"), force=true)
end

function Base.write(dest::String, reqs::MarsRequests)
    for req in reqs
        Base.write(dest, req)
    end
end

function format(fcontrol::FlexControl)::Vector{String}
    str = []
    for (k, v) in fcontrol.control
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

function set_area!(fcontrol::FlexControl, area)
    new = Dict(
        :LOWER => area[3] isa String || string(area[3]), 
        :UPPER => area[1] isa String || string(area[1]), 
        :LEFT => area[2] isa String || string(area[2]), 
        :RIGHT => area[4] isa String || string(area[4]),
    )
    set!(fcontrol, new)
end

function set_steps!(fcontrol::FlexControl, startdate, enddate, timestep)
    stepdt = startdate:Dates.Hour(timestep):(enddate - Dates.Hour(1))
    type_ctrl = []
    time_ctrl = []
    step_ctrl = []

    format_opt = opt -> opt < 10 ? "0$(opt)" : "$(opt)"
    for (i, st) in enumerate(stepdt)
        push!(time_ctrl, div(Dates.Hour(st).value, 12) * 12 |> format_opt)
        step = Dates.Hour(st).value .% 12
        step == 0 ? push!(type_ctrl, "AN") : push!(type_ctrl, "FC")
        push!(step_ctrl, step |> format_opt)
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


function set!(fcontrol::FlexControl, newv::Dict{Symbol, <:Any})
    merge!(fcontrol.control, newv)
end


Base.getindex(fcontrol::FlexControl, name::ControlItem) = fcontrol.control[name]
function Base.setindex!(fcontrol::FlexControl, val, name::ControlItem)
    fcontrol.control[name] = val
end

Base.getindex(req::MarsRequest, name::Symbol) = req.dict[name]
function Base.setindex!(req::MarsRequest, val, name::Symbol)
    req.dict[name] = val
end

# function Base.getproperty(req::MarsRequest, name::Symbol) 
#     if name !== :dict
#         req.dict[name]
#     else
#         getfield(req, name)
#     end
# end
# function Base.setproperty!(req::MarsRequest, val, name::Symbol)
#     req.dict[name] = val
# end
Base.iterate(req::MarsRequest, i...) = Base.iterate(req.dict, i...)
# function format_opt(opt::Int)
#     opt < 10 ? "0$(opt)" : "$(opt)"
# end

