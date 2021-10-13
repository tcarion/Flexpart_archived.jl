const FLEX_DEFAULT_CONTROL = "CONTROL_OD.OPER.FC.eta.highres.app"
const PYTHON_RETRIEVE_SCRIPT = joinpath(@__DIR__, "pypolytope.py")
const FlexextractPath = String

const ControlItem = Symbol
const ControlFilePath = String

const FeControl= OrderedDict{ControlItem, Any}
struct FlexControl
    path::ControlFilePath
    control::FeControl
end
FlexControl(path::String) = FlexControl(abspath(path), control2dict(path))
Base.show(io::IO, fcontrol::FlexControl) = print(io, "FlexControl with fields :\n", fcontrol.control)


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
        write(newcontrol)
        new(fepath, newcontrol, inputdir, outputdir, controlname)
    end
end
function FlexextractDir(fepath::FlexextractPath)
    files = readdir(fepath, join=true)
    icontrol = findfirst(x -> occursin("CONTROL", x), files .|> basename)
    isnothing(icontrol) && error("FlexExtract dir has no Control file")
    FlexextractDir(fepath, FlexControl(files[1]))
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


submitcmd(fedir::FlexextractDir, fesource::FeSource) = `$(fesource.python) $(fesource.scripts[:submit]) $(feparams(fedir))`

function submit(fedir::FlexextractDir, fesource::FeSource; async=false)
    # params = feparams(fedir)
    # cmd = `$(fesource.python) $(fesource.scripts[:submit]) $(params)`
    cmd = submitcmd(fedir, fesource)
    if async
        open(joinpath(fedir.path, "fe_run.log"), "w") do f
            Base.run(pipeline(cmd, f))
        end
    else
        Base.run(cmd)
    end 
    println("The following command has been run : $cmd")
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

function retrieve(fesource::FeSource, requests::MarsRequests)
    mktempdir() do dir
        for req in requests
            cmd = retrievecmd(fesource, req, dir)
            run(cmd)
        end
    end
end

function retrieve(f::Function, fesource::FeSource, requests::MarsRequests)
    mktempdir() do dir
        for req in requests
            cmd = retrievecmd(fesource, req, dir)
            pipe = Pipe()

            @async while true
                f(pipe)
            end

            run(pipeline(cmd, stdout=pipe, stderr=pipe))
        end
    end
end

function preparecmd(fedir::FlexextractDir, fesource::FeSource)
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

function prepare(fedir::FlexextractDir, fesource::FeSource)
    cmd = preparecmd(fedir, fesource)
    run(cmd)
end

function prepare(f::Function, fedir::FlexextractDir, fesource::FeSource)
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
feparams(fedir::FlexextractDir) = feparams(fedir.controlpath, fedir.inpath, fedir.outpath)

function scripts(installpath::String)
    Dict(
        :run_local => joinpath(installpath, "Run", "run_local.sh"),
        :submit => joinpath(installpath, "Source", "Python", "submit.py"),
        :prepare => joinpath(installpath, "Source", "Python", "Mods", "prepare_flexpart.py"),
    )
end

csvpath(fedir::FlexextractDir) = joinpath(fedir.inpath, "mars_requests.csv")

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

function write(fcontrol::FlexControl)
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
set_area!(fedir::FlexextractDir, area) = set_area!(fedir.control, area)

function set_steps!(fcontrol::FlexControl, startdate, enddate, timestep)
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
set_steps!(fedir::FlexextractDir, startdate, enddate, timestep) = set_steps!(fedir.control, startdate, enddate, timestep)

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

