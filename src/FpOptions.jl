module FpOptions

import Flexpart: FlexpartDir, SimType, Deterministic, Ensemble, getdir
import DataStructures: OrderedDict
using Dates

export 
    FlexpartOptions,
    set!,
    set,
    set_area!,
    set_steps!,
    area2outgrid

struct NotNamelistError <: Exception
    filename::String
end
Base.showerror(io::IO, e::NotNamelistError) = print("Namelist format not valid : ", e.filename)

const OptionHeader = Symbol
const OptionFileName = String

const OptionBody = OrderedDict{Symbol, Any}
const OptionBodys = Vector{OptionBody}

const OptionsGroup = Dict{OptionHeader, OptionBodys}

const FileOptions = Dict{OptionFileName, OptionsGroup}

struct FlexpartOptions{T}
    fpdir::FlexpartDir{T}
    options::FileOptions
end
const OPTION_FILE_NAMES = ["COMMAND", "RELEASES", "OUTGRID", "OUTGRID_NEST"]

function to_fpoption(fpdir::FlexpartDir, name::OptionFileName)
    name = name |> uppercase
    namelist2dict(joinpath(getdir(fpdir, :options), name))
end

FlexpartOptions(path::String) = FlexpartOptions(FlexpartDir(path))

function FlexpartOptions(fpdir::FlexpartDir{T}) where T
    FlexpartOptions{T}(
        fpdir, 
        getnamelists(getdir(fpdir, :options))
    )
end
Base.getindex(fp::FlexpartOptions, name::OptionFileName) = fp.options[name]
function Base.setindex!(fp::FlexpartOptions, value, name::OptionFileName)
    fp.options[name] = value
end
Base.keys(fpoptions::FlexpartOptions) = Base.keys(fpoptions.options)
getfpdir(fpoptions::FlexpartOptions) = fpoptions.fpdir

function add(fpoptions::FlexpartOptions, name::OptionFileName, header::OptionHeader, value)
    optionbody = convert(OptionBody, value)
    group = OptionsGroup(header => [optionbody])
    fpoptions[name] = group
end

function getnamelists(path::String)
    fileoptions = FileOptions()
    for (root, dirs, files) in walkdir(path)
        for file in files
            rel = basename(relpath(path, root))
            name = root == path ? file : joinpath(relpath(root, path), file)
            absfile = joinpath(root, file)
            dict = try
                namelist2dict(absfile)
            catch e
                if e isa NotNamelistError
                    nothing
                else
                    throw(e)
                end
            end
            !isnothing(dict) && push!(fileoptions, name => dict)
        end
    end
    fileoptions
end

function format(options::OptionsGroup)::Vector{String}
    str = []
    for (header, fpoptions) in options
        for line in option2lines(header, fpoptions)
            push!(str, line)
        end
    end
    str
end

function option2lines(header::Symbol, options::OptionBodys) :: Vector{String}
    head = header |> string |> uppercase
    str = String[]
    for option in options
        push!(str, "&$(head)")
        for line in body2lines(option)
            push!(str, line)
        end
    end
    str
end
function body2lines(body::OptionBody) :: Vector{String}
    str = String[]
    for (k, v) in body
        key = uppercase(String(k))
        push!(str, " $key = $v,")
    end
    push!(str, " /")
    str
end

function area2outgrid(area::Vector{<:Real}, gridres=0.01; nested=false)
    outlon0 = area[2]
    outlat0 = area[3]
    Δlon = area[4] - outlon0
    Δlat = area[1] - outlat0
    (numxgrid, numygrid) = try
        convert(Int, Δlon/gridres), convert(Int, Δlat/gridres)
    catch
        error("gridres must divide area")
    end
    dxout = gridres
    dyout = gridres
    res = OrderedDict(
        :OUTLON0 => outlon0, :OUTLAT0 => outlat0, :NUMXGRID => numxgrid, :NUMYGRID => numygrid, :DXOUT => dxout, :DYOUT => dyout,
    )
    nested ? Dict(
        String(k)*'N' |> Symbol => v for (k, v) in res
    ) : res
end

function area2outgrid(fpdir::FlexpartDir, gridres::Real; nested=false)
    firstinput = readdir(getdir(fpdir, :input), join=true)[1]
    area = grib_area(firstinput)

    area2outgrid(area, gridres; nested)
end

function set!(option::OptionBody, newv)
    newv = newv isa Pair ? Dict(newv) : newv
    merge!(option, newv)
end
function set(option::OptionBody, newv)
    newv = newv isa Pair ? Dict(newv) : newv
    merge(option, newv)
end

function setfromdates!(fpoptions::FlexpartOptions, start::DateTime, finish::DateTime)
    toset = OrderedDict(
        :IBDATE => Dates.format(start, "yyyymmdd"),
        :IEDATE => Dates.format(finish, "yyyymmdd"),
        :IBTIME => Dates.format(start, "HHMMSS"),
        :IETIME => Dates.format(finish, "HHMMSS"),
    )
    set!(fpoptions["COMMAND"][:command][1], toset)
end

# function setrelease!(fpoptions::FlexpartOptions, start::DateTime, finish::DateTime)
#     set!(fpoptions["RELEASE"][:command][1], toset)
# end

function write(flexpartoption::FlexpartOptions, newpath::String = "")
    options_dir = newpath == "" ? getdir(getfpdir(flexpartoption), :options) : joinpath(newpath, OPTIONS_DIR)
    try 
        mkdir(options_dir)
    catch
    end

    for (name, options) in flexpartoption.options
        filepath = joinpath(options_dir, name)
        write(options, filepath)
    end
end
function write(options::OptionsGroup, path::String)
    (tmppath, tmpio) = mktemp()

    for line in format(options) Base.write(tmpio, line*"\n") end

    close(tmpio)
    dest = path

    mv(tmppath, dest, force=true)
end

diffkeys(dict1, dict2) = [k for k in keys(dict1) if dict1[k] != get(dict2, k, nothing)]

function compare(opt1::OptionsGroup, opt2::OptionsGroup)
    d = Dict()
    for (header, fpoption) in opt1
        push!(d, header => [diffkeys(d1, opt2[header][i]) for (i, d1) in enumerate(fpoption)])
    end
    println("HEADER \t NAME \t FILE1 \t FILE2")
    for (header, v) in d
        println(header)
        for (i, opt) in enumerate(v)
            for name in opt
                println("      \t $name \t $(opt1[header][i][name]) \t $(opt2[header][i][name])")
            end
        end
    end
    d
end

function compare(file1::String, file2::String)
    opt1 = namelist2dict(file1)
    opt2 = namelist2dict(file2)
    compare(opt1, opt2)
    # diffs
end

function compare(fpdir1::FlexpartDir, fpdir2::FlexpartDir, filename1::String; filename2::String = "", which = :output)
    filename2 = filename2 |> isempty ? filename1 : filename2
    file1 = joinpath(getdir(fpdir1, which), filename1)
    file2 = joinpath(getdir(fpdir2, which), filename2)
    compare(file1, file2)
end

function namelist2dict(filepath)
    lines = readlines(filepath)
    reg_header = r"\&(\w*)"
    # match only '/' that are not between brackets. 
    # src: https://stackoverflow.com/questions/11502598/how-to-match-something-with-regex-that-is-not-between-two-special-characters
    reg_endofbody = r"\/(?=(?:[^\"]*\"[^\"]*\")*[^\"]*\Z)" 
    cleared = [split(line, '!')[1] for line in lines] # remove the comments
    iheader = findall(line -> !isnothing(match(reg_header, line)), cleared) # find headers
    iend = findall(line -> !isnothing(match(reg_endofbody, line)), cleared) # find end of body
    (length(iheader) == 0 || (length(iheader) !== length(iend))) && throw(NotNamelistError(filepath))
    bodys = [lines[i:j] for (i, j) in zip(iheader, iend)]
    headers = lines[iheader]
    headers = [match(reg_header, line).captures[1] |> lowercase |> Symbol for line in headers]
    optgroup = OptionsGroup(k => OptionBody[] for k in unique(headers))
    # optgroup = Dict(k => Dict{Symbol, Any}[] for k in unique(headers))
    for (n, header) in enumerate(headers)
        push!(optgroup[header], lines2option(bodys[n]))
    end
    optgroup
end

function lines2option(lines::Vector{String})
    opt = OptionBody()
    for line in lines
        if !((m = match(r"\s*(.*?)\s*=\s*(\".*?\"|[^\s,]*)\s*,", line)) |> isnothing) #captures the field name in group 1 and the value in group 2
            push!(opt, m.captures[1] |> Symbol => m.captures[2])
        end
    end
    opt
end

end