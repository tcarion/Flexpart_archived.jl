module FlexpartOptions

using ..Flexpart: FlexpartDir, grib_area, writelines, OPTIONS_DIR_DEFAULT
import ..Flexpart

using DataStructures: OrderedDict
using Dates

export 
    FlexpartOption,
    # set!,
    set,
    setfromdates!,
    area2outgrid

struct NotNamelistError <: Exception
    filename::String
end
Base.showerror(io::IO, e::NotNamelistError) = print(io, "Namelist format not valid : ", e.filename)

# abstract type IndexableOption end
# function Base.getindex(sub::IndexableOption, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::IndexableOption, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end
mutable struct OptionEntry
    name::Symbol
    value::String
    # default::String
    doc::String
end
function OptionEntry(line::String)
    # Separate the name, value and comment.
    reg = r"(.*?)=(.*?),(\s*!(.*))?"
    m = match(reg, line)
    na, val, _, doc = m
    name = Symbol(strip(na))
    value = string(strip(val))
    doc = isnothing(doc) ? "" : string(lstrip(doc))
    OptionEntry(name, value, doc)
end
# function Base.getindex(sub::OptionEntry, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::OptionEntry, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end
function Base.show(io::IO, ::MIME"text/plain", entry::OptionEntry)
    println(io, "$(entry.name) => $(entry.value)")
    !isempty(entry.doc) && printstyled(io, entry.doc*".", color=:cyan)
end

struct Entries
   vec::Vector{<:OptionEntry}
end
function Base.getindex(entries::Entries, name::Symbol)
    i = findfirst(x -> x.name == name, entries.vec)
    entries.vec[i]
end
function Base.setindex!(entries::Entries, val, name::Symbol)
    i = findfirst(x -> x.name == name, entries.vec)
    entries.vec[i].value = string(val)
end
Base.iterate(entries::Entries) = iterate(entries.vec)
Base.iterate(entries::Entries, state) = iterate(entries.vec, state)
# Base.iterate(entries::Entries, ::Int64) = iterate(entries.vec, ::Int64)
Entries() = Entries(Vector{OptionEntry}(undef, 0))

const UniqueSubOption = Entries
const MultSubOption = Vector{Entries}
mutable struct SubOption{T}
    name::Symbol
    entries::T
end
Base.getindex(sub::SubOption{UniqueSubOption}, name::Symbol) = getindex(sub.entries, name)
Base.setindex!(sub::SubOption{UniqueSubOption}, val, name::Symbol) = setindex!(sub.entries, val, name)

Base.getindex(sub::SubOption{MultSubOption}, i::Int) = sub.entries[i]
Base.setindex!(sub::SubOption{MultSubOption}, val, i::Int) = sub.entries[i].value = string(val)

# function SubOption(name::Symbol, lines::AbstractVector{String})
#     entries = [OptionEntry(line) for line in lines]
#     SubOption(name, entries)
# end
function SubOption{UniqueSubOption}(name::Symbol, lines::AbstractVector{String})
    entries = Entries([OptionEntry(line) for line in lines])
    SubOption{UniqueSubOption}(name, entries)
end
# function SubOption{MultSubOption}(name::Symbol)
#     SubOption{MultSubOption}(name, Vector{Vector{OptionEntry}}(undef, 0))
# end
SubOption(name::Symbol, lines::AbstractVector{String}) = SubOption{UniqueSubOption}(name, lines)
function SubOption{T}(name::Symbol) where T <: MultSubOption
    # entries = [OptionEntry(line) for line in lines]
    SubOption{T}(name, Vector{MultSubOption}(undef, 0))
end
Base.push!(sub::SubOption{MultSubOption}, entries) = push!(sub.entries, entries)
function Base.convert(T::Type{SubOption{MultSubOption}}, x::SubOption{UniqueSubOption})
    # entries =  MultSubOption()
    s = T(x.name)
    push!(s.entries, x.entries)
    s
end
# function Base.getindex(sub::SubOption{MultSubOption}, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::SubOption, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end
findparam(::SubOption{T}) where T = T

const FileOptionType = String
mutable struct Option
    name::FileOptionType
    subopts::AbstractVector{SubOption}
end
Option(name::FileOptionType) = Option(name, Vector{SubOption}())
function add_option(opt::Option, sub::SubOption{UniqueSubOption})
    if sub in opt
        cursub = opt[sub.name]
        if findparam(cursub) == UniqueSubOption
            opt[sub.name] = convert(SubOption{MultSubOption}, cursub)
        end
        push!(opt[sub.name], sub.entries)
    else
        push!(opt, sub)
    end
end
function Base.getindex(opt::Option, name::Symbol)
    i = findfirst(x -> x.name == name, opt.subopts)
    opt.subopts[i]
end
function Base.setindex!(opt::Option, val, name::Symbol)
    i = findfirst(x -> x.name == name, opt.subopts)
    opt.subopts[i] = val
end
Base.in(sub::SubOption, option::Option) = in(sub.name, [s.name for s in option.subopts])
Base.push!(opt::Option, sub::SubOption) = push!(opt.subopts, sub)

function parse_namelist(filepath; name = "")::Option
    filename = basename(filepath)
    lines = readlines(filepath)
    reg_header = r"^\&(\w*)"
    iheader = findall(line -> !isnothing(match(reg_header, strip(line))), lines) # find headers
    iend = findall(line -> strip(line) == "/", lines) # find end of body

    (length(iheader) == 0 || (length(iheader) !== length(iend))) && throw(NotNamelistError(filepath))
    bodys = [lines[i+1:j-1] for (i, j) in zip(iheader, iend)]
    headers = lines[iheader]
    headers = [match(reg_header, line).captures[1] |> uppercase |> Symbol for line in headers]

    suboptions = [SubOption(header, body) for (header, body) in zip(headers, bodys)]
    opt = isempty(name) ? Option(filename) : Option(name)
    for s in suboptions
        add_option(opt, s)
    end
    # Option(Symbol(filename), suboptions)
    opt
end

# const OptionHeader = Symbol
# const OptionFileName = String

# const OptionBody = OrderedDict{Symbol, Any}
# const OptionBodys = Vector{OptionBody}

# const OptionsGroup = Dict{OptionHeader, OptionBodys}

# const FileOptions = Dict{OptionFileName, OptionsGroup}

struct FlexpartOption
    dirpath::String
    options::AbstractVector{Option}
end
# const OPTION_FILE_NAMES = ["COMMAND", "RELEASES", "OUTGRID", "OUTGRID_NEST"]

# function to_fpoption(fpdir::FlexpartDir, name::OptionFileName)
#     name = name |> uppercase
#     namelist2dict(joinpath(fpdir[:options], name))
# end

FlexpartOption(path::String) = FlexpartOption(path, walkoptions(path))

FlexpartOption(fpdir::FlexpartDir) = FlexpartOption(fpdir[:options])

function Base.getindex(fp::FlexpartOption, name::FileOptionType)
    i = findfirst(x -> x.name == name, fp.options)
    fp.options[i]
end
function Base.setindex!(fp::FlexpartOption, value, name::FileOptionType)
    i = findfirst(x -> x.name == name, fp.options)
    fp.options[i].value = value
end
Base.keys(fpoptions::FlexpartOption) = [x.name for x in fpoptions.options]
Base.iterate(fpoptions::FlexpartOption) = iterate(fpoptions.options)
Base.iterate(fpoptions::FlexpartOption, state) = iterate(fpoptions.options, state)
# getfpdir(fpoptions::FlexpartOption) = fpoptions.fpdir

# function add(fpoptions::FlexpartOption, name::FileOptionType, header::OptionHeader, value)
#     optionbody = convert(OptionBody, value)
#     group = OptionsGroup(header => [optionbody])
#     fpoptions[name] = group
# end

function walkoptions(path::String)
    fileoptions = Vector{Option}()
    for (root, _, files) in walkdir(path)
        for file in files
            # rel = basename(relpath(path, root))
            name = root == path ? file : joinpath(relpath(root, path), file)
            absfile = joinpath(root, file)
            opt = try
                parse_namelist(absfile, name = name)
            catch e
                if e isa NotNamelistError
                    nothing
                else
                    rethrow()
                end
            end
            # push!(fileoptions, name => opt)
            !isnothing(opt) && push!(fileoptions, opt)
        end
    end
    fileoptions
end

# function getnamelists(path::String)
#     fileoptions = FileOptions()
#     for (root, dirs, files) in walkdir(path)
#         for file in files
#             rel = basename(relpath(path, root))
#             name = root == path ? file : joinpath(relpath(root, path), file)
#             absfile = joinpath(root, file)
#             dict = try
#                 namelist2dict(absfile)
#             catch e
#                 if e isa NotNamelistError
#                     nothing
#                 else
#                     throw(e)
#                 end
#             end
#             !isnothing(dict) && push!(fileoptions, name => dict)
#         end
#     end
#     fileoptions
# end

# function format(options::OptionsGroup)::Vector{String}
#     str = []
#     for (header, fpoptions) in options
#         for line in option2lines(header, fpoptions)
#             push!(str, line)
#         end
#     end
#     str
# end

function format(entry::OptionEntry)
    " $(entry.name) = $(entry.value), ! $(entry.doc)"
end

function format(entries::Entries)
    lines = String[]
    for e in entries
        push!(lines, format(e))
    end
    lines
end

function format(sub::SubOption{UniqueSubOption})
    head = sub.name |> string |> uppercase
    lines = String[]
    push!(lines, "&$(head)")
    push!(lines, format(sub.entries)...)
    push!(lines, " /")
    lines 
end

function format(sub::SubOption{MultSubOption})
    head = sub.name |> string |> uppercase
    lines = String[]
    for entries in sub.entries
        push!(lines, "&$(head)")
        push!(lines, format(entries)...)
        push!(lines, " /")
    end
    lines
end

function format(opt::Option)
    lines = String[]
    for sub in opt.subopts
        push!(lines, format(sub)...)
    end
    lines
end

function Flexpart.write(flexpartoption::FlexpartOption, newpath::String = "")
    options_dir = newpath == "" ? flexpartoption.dirpath : newpath
    try 
        mkdir(options_dir)
    catch
    end

    for option in flexpartoption
        filepath = joinpath(options_dir, option.name)
        writelines(filepath, format(option))
    end
end

# function option2lines(header::Symbol, options::OptionBodys)
#     head = header |> string |> uppercase
#     str = String[]
#     for option in options
#         push!(str, "&$(head)")
#         for line in body2lines(option)
#             push!(str, line)
#         end
#     end
#     str
# end
# function body2lines(body::OptionBody)
#     str = String[]
#     for (k, v) in body
#         key = uppercase(String(k))
#         push!(str, " $key = $v,")
#     end
#     push!(str, " /")
#     str
# end

function area2outgrid(area::Vector{<:Real}, gridres=0.01; nested=false)
    outlon0 = area[2]
    outlat0 = area[3]
    Δlon = area[4] - outlon0
    Δlat = area[1] - outlat0
    Δlon, Δlat = round.([Δlon, Δlat], digits=7)
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
    firstinput = readdir(fpdir[:input], join=true)[1]
    area = grib_area(firstinput)

    area2outgrid(area, gridres; nested)
end

# function Flexpart.set!(option::OptionBody, newv)
#     newv = newv isa Pair ? Dict(newv) : newv
#     merge!(option, newv)
# end
# function set(option::OptionBody, newv)
#     newv = newv isa Pair ? Dict(newv) : newv
#     merge(option, newv)
# end

function setfromdates!(fpoptions::FlexpartOption, start::DateTime, finish::DateTime)
    toset = OrderedDict(
        :IBDATE => Dates.format(start, "yyyymmdd"),
        :IEDATE => Dates.format(finish, "yyyymmdd"),
        :IBTIME => Dates.format(start, "HHMMSS"),
        :IETIME => Dates.format(finish, "HHMMSS"),
    )
    merge!(fpoptions["COMMAND"][:command][1], toset)
end

# function setrelease!(fpoptions::FlexpartOptions, start::DateTime, finish::DateTime)
#     set!(fpoptions["RELEASE"][:command][1], toset)
# end

# function write(options::OptionsGroup, path::String)
#     (tmppath, tmpio) = mktemp()

#     for line in format(options) Base.write(tmpio, line*"\n") end

#     close(tmpio)
#     dest = path

#     mv(tmppath, dest, force=true)
# end

diffkeys(dict1, dict2) = [k for k in keys(dict1) if dict1[k] != get(dict2, k, nothing)]

# function compare(opt1::OptionsGroup, opt2::OptionsGroup)
#     d = Dict()
#     for (header, fpoption) in opt1
#         push!(d, header => [diffkeys(d1, opt2[header][i]) for (i, d1) in enumerate(fpoption)])
#     end
#     println("HEADER \t NAME \t FILE1 \t FILE2")
#     for (header, v) in d
#         println(header)
#         for (i, opt) in enumerate(v)
#             for name in opt
#                 println("      \t $name \t $(opt1[header][i][name]) \t $(opt2[header][i][name])")
#             end
#         end
#     end
#     d
# end

function compare(file1::String, file2::String)
    opt1 = namelist2dict(file1)
    opt2 = namelist2dict(file2)
    compare(opt1, opt2)
    # diffs
end

function compare(fpdir1::FlexpartDir, fpdir2::FlexpartDir, filename1::String; filename2::String = "", which = :output)
    filename2 = filename2 |> isempty ? filename1 : filename2
    file1 = joinpath(Flexpart.abspath(fpdir1, which), filename1)
    file2 = joinpath(Flexpart.abspath(fpdir2, which), filename2)
    compare(file1, file2)
end

# function namelist2dict(filepath)
#     lines = readlines(filepath)
#     reg_header = r"\&(\w*)"
#     # match only '/' that are not between brackets. 
#     # src: https://stackoverflow.com/questions/11502598/how-to-match-something-with-regex-that-is-not-between-two-special-characters
#     reg_endofbody = r"\/(?=(?:[^\"]*\"[^\"]*\")*[^\"]*\Z)" 
#     cleared = [split(line, '!')[1] for line in lines] # remove the comments
#     iheader = findall(line -> !isnothing(match(reg_header, line)), cleared) # find headers
#     iend = findall(line -> !isnothing(match(reg_endofbody, line)), cleared) # find end of body
#     (length(iheader) == 0 || (length(iheader) !== length(iend))) && throw(NotNamelistError(filepath))
#     bodys = [lines[i:j] for (i, j) in zip(iheader, iend)]
#     headers = lines[iheader]
#     headers = [match(reg_header, line).captures[1] |> lowercase |> Symbol for line in headers]
#     optgroup = OptionsGroup(k => OptionBody[] for k in unique(headers))
#     # optgroup = Dict(k => Dict{Symbol, Any}[] for k in unique(headers))
#     for (n, header) in enumerate(headers)
#         push!(optgroup[header], lines2option(bodys[n]))
#     end
#     optgroup
# end

# function lines2option(lines::Vector{String})
#     opt = OptionBody()
#     for line in lines
#         if !((m = match(r"\s*(.*?)\s*=\s*(\".*?\"|[^\s,]*)\s*,", line)) |> isnothing) #captures the field name in group 1 and the value in group 2
#             push!(opt, m.captures[1] |> Symbol => m.captures[2])
#         end
#     end
#     opt
# end

end