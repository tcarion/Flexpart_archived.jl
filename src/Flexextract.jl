# const FLEX_EXTRACT_PATH = "/home/tcarion/flexpart/flex_extract_v7.1.2"
const FLEX_DEFAULT_CONTROL = "CONTROL_OD.OPER.FC.eta.highres.app"
const FLEX_EXTRACT_RUN_PATH = joinpath(FLEX_EXTRACT_PATH, "Run")
const FLEX_EXTRACT_SOURCE_PYTHON_PATH = joinpath(FLEX_EXTRACT_PATH, "Source", "Python")
const FLEX_EXTRACT_CONTROL_PATH = joinpath(FLEX_EXTRACT_RUN_PATH, "Control", FLEX_EXTRACT_CONTROL)
const FLEX_EXTRACT_EXEC_PATH = joinpath(FLEX_EXTRACT_RUN_PATH, "run_local.sh")
const FLEX_EXTRACT_SUBMIT_PATH = joinpath(FLEX_EXTRACT_SOURCE_PYTHON_PATH, "submit.py")


const ControlItem = Symbol
const ControlFileName = String

const FeControl= OrderedDict{ControlItem, Any}

# const OptionsGroup = Dict{Symbol, FpOption}

# const FileOptions = Dict{OptionFileName, OptionsGroup}

struct FlexControl
    path::ControlFileName
    control::FeControl
end
FlexControl(path::String) = FlexControl(abspath(path), control2dict(path))


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

function Base.write(fcontrol::FlexControl, newpath::String = "")
    dest = newpath == "" ? fcontrol.path : newpath

    (tmppath, tmpio) = mktemp()

    for line in format(fcontrol) Base.write(tmpio, line*"\n") end

    close(tmpio)
    mv(tmppath, dest, force=true)

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

