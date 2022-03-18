module FlexpartOptions

using ..Flexpart: FlexpartDir, grib_area, writelines
import ..Flexpart

using DataStructures: OrderedDict
using Dates

export
    FlexpartOption,
    # set!,
    set,
    value,
    area2outgrid,
    removeall!

struct NotNamelistError <: Exception
    filename::String
end
Base.showerror(io::IO, e::NotNamelistError) = print(io, "Namelist format not valid : ", e.filename)

struct NotInOptionError <: Exception 
    key::Symbol
end
Base.showerror(io::IO, e::NotInOptionError) = print(io, "Key :$(e.key) is not in the option entry list.")

# abstract type IndexableOption end
# function Base.getindex(sub::IndexableOption, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::IndexableOption, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end

function _findoption(key, fieldn, vec)
    i = findfirst(x -> getfield(x, fieldn) == key, vec)
    isnothing(i) && throw(NotInOptionError(key)) # Exception is thrown if the key is not in the entry list
    i
end
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
    na, val, _, doc = m.captures
    name = Symbol(strip(na))
    value = string(strip(val))
    doc = isnothing(doc) ? "" : string(lstrip(doc))
    OptionEntry(name, value, doc)
end
value(entry::OptionEntry) = entry.value
# Base.copy(entry::OptionEntry) = OptionEntry(entry.name, entry.value, entry.doc)
# function Base.getindex(sub::OptionEntry, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::OptionEntry, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end
function Base.show(io::IO, ::MIME"text/plain", entry::OptionEntry)
    print(io, "$(entry.name) = $(entry.value)")
    !isempty(entry.doc) && printstyled(io, "\t! " * entry.doc * ".", color = :cyan)
    print(io, "\n")
end

struct Entries{T<:OptionEntry} <: AbstractVector{T}
    vec::Vector{T}
end
Entries() = Entries(Vector{OptionEntry}(undef, 0))
Base.size(entries::Entries) = size(entries.vec)
Base.getindex(entries::Entries, i::Int) = entries.vec[i]
Base.setindex!(entries::Entries, v, i::Int) = entries.vec[i] = v
function Base.getindex(entries::Entries, name::Symbol)
    i = _findoption(name, :name, entries.vec)
    entries.vec[i]
end
function Base.setindex!(entries::Entries, val, name::Symbol)
    i = _findoption(name, :name, entries.vec)
    entries.vec[i].value = string(val)
end
# Base.iterate(entries::Entries) = iterate(entries.vec)
# Base.iterate(entries::Entries, state) = iterate(entries.vec, state)
Base.keys(entries::Entries) = [x.name for x in entries]
# Base.deepcopy(entries::Entries) = Entries(deepcopy(entries.vec))
function Base.show(io::IO, m::MIME"text/plain", entries::Entries)
    for e in entries
        show(io, m, e)
    end
end

const SingleEntries = Entries
const MultipleEntries = Vector{Entries}
mutable struct OptionGroup{T<:Union{SingleEntries,MultipleEntries}}
    name::Symbol
    entries::T
end
function Base.show(io::IO, m::MIME"text/plain", group::OptionGroup{<:SingleEntries})
    # println(io, "Goup name $(group.name) with single entries")
    show(io, m, group.entries)
end
function Base.show(io::IO, ::MIME"text/plain", group::OptionGroup{<:MultipleEntries})
    println(io, "Goup name $(group.name) with $(length(group.entries)) entries")
end
Base.getindex(group::OptionGroup{<:SingleEntries}, name::Symbol) = getindex(group.entries, name)
Base.setindex!(group::OptionGroup{<:SingleEntries}, val, name::Symbol) = setindex!(group.entries, val, name)

Base.getindex(group::OptionGroup{<:MultipleEntries}, i::Int) = OptionGroup(group.name, group.entries[i])

Base.iterate(group::OptionGroup{<:MultipleEntries}) = iterate(group.entries)
Base.iterate(group::OptionGroup{<:MultipleEntries}, i) = iterate(group.entries, i)
# Base.setindex!(group::SubOption{MultipleEntries}, val, i::Int) = group.entries[i].value = string(val)

Base.keys(group::OptionGroup{<:SingleEntries}) = keys(group.entries)
Base.keys(group::OptionGroup{<:MultipleEntries}) = keys(group.entries[1])

function Base.merge!(group::OptionGroup{<:SingleEntries}, d::AbstractDict)
    for (k, v) in d
        group[k] = v
    end
end
# function SubOption(name::Symbol, lines::AbstractVector{String})
#     entries = [OptionEntry(line) for line in lines]
#     SubOption(name, entries)
# end
function OptionGroup{SingleEntries}(name::Symbol, lines::AbstractVector{String})
    entries = Entries([OptionEntry(line) for line in lines])
    OptionGroup{SingleEntries}(name, entries)
end
# function SubOption{MultipleEntries}(name::Symbol)
#     SubOption{MultipleEntries}(name, Vector{Vector{OptionEntry}}(undef, 0))
# end
OptionGroup(name::Symbol, lines::AbstractVector{String}) = OptionGroup{SingleEntries}(name, lines)
function OptionGroup{T}(name::Symbol) where {T<:MultipleEntries}
    # entries = [OptionEntry(line) for line in lines]
    OptionGroup{T}(name, MultipleEntries(undef, 0))
end
Base.push!(group::OptionGroup{<:MultipleEntries}, entries::Entries) = push!(group.entries, entries)
function Base.convert(T::Type{OptionGroup{MultipleEntries}}, x::OptionGroup{SingleEntries})
    # entries =  MultipleEntries()
    s = T(x.name)
    push!(s.entries, x.entries)
    s
end
function Base.deepcopy(group::OptionGroup{<:SingleEntries})
    OptionGroup{SingleEntries}(group.name, deepcopy(group.entries))
end
# function Base.getindex(sub::SubOption{MultipleEntries}, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i]
# end
# function Base.setindex!(sub::SubOption, val, name::Symbol)
#     i = findfirst(x -> x.name == name, sub.entries)
#     sub.entries[i].value = string(val)
# end
findparam(::OptionGroup{T}) where {T} = T

const FileOptionType = String
mutable struct Option
    name::FileOptionType
    groups::AbstractVector{OptionGroup}
end
Option(name::FileOptionType) = Option(name, Vector{OptionGroup}())
function Base.show(io::IO, m::MIME"text/plain", opt::Option)
    println(io, "Option $(opt.name) with group(s):")
    for group in opt.groups
        println(io, group.name)
    end
end

function add_option(opt::Option, group::OptionGroup{<:SingleEntries})
    if group in opt
        curgroup = opt[group.name]
        if findparam(curgroup) == SingleEntries
            opt[group.name] = convert(OptionGroup{MultipleEntries}, curgroup)
        end
        push!(opt[group.name], group.entries)
    else
        push!(opt, group)
    end
end
function Base.getindex(opt::Option, name::Symbol)
    i = _findoption(name, :name, opt.groups)
    opt.groups[i]
end
function Base.setindex!(opt::Option, val, name::Symbol)
    i = _findoption(name, :name, opt.groups)
    opt.groups[i] = val
end
Base.keys(opt::Option) = [group.name for group in opt.groups]
Base.in(group::OptionGroup, option::Option) = in(group.name, [s.name for s in option.groups])
function Base.push!(opt::Option, group::OptionGroup{<:SingleEntries})
    if group in opt
        if findparam(opt[group.name]) == MultipleEntries
            push!(opt[group.name], group.entries)
        else
            multgroup = convert(OptionGroup{MultipleEntries}, opt[group.name])
            push!(multgroup, group.entries)
            filter!(x -> x !== opt[group.name], opt.groups)
            push!(opt, multgroup)
        end
    else
        push!(opt.groups, group)
    end
end
function Base.push!(opt::Option, group::OptionGroup{<:MultipleEntries})
    if group in opt
        for entries in group.entries
            push!(opt[group.name], entries)
        end
    else
        push!(opt.groups, group)
    end
end
function removeall!(opt::Option, name::Symbol)
    filter!(group -> group.name !== name, opt.groups)
end


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

    suboptions = [OptionGroup(header, body) for (header, body) in zip(headers, bodys)]
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
function Base.show(io::IO, ::MIME"text/plain", fpopt::FlexpartOption)
    println(io, "FlexpartOption @ $(fpopt.dirpath) with options:")
    for opt in fpopt.options
        println(io, opt.name)
    end
end
# const OPTION_FILE_NAMES = ["COMMAND", "RELEASES", "OUTGRID", "OUTGRID_NEST"]

# function to_fpoption(fpdir::FlexpartDir, name::OptionFileName)
#     name = name |> uppercase
#     namelist2dict(joinpath(fpdir[:options], name))
# end

FlexpartOption(path::String) = FlexpartOption(path, walkoptions(path))

FlexpartOption(fpdir::FlexpartDir) = FlexpartOption(fpdir[:options])

function Base.getindex(fp::FlexpartOption, name::FileOptionType)
    i = _findoption(name, :name, fp.options)
    fp.options[i]
end
function Base.setindex!(fp::FlexpartOption, value, name::FileOptionType)
    i = _findoption(name, :name, fp.options)
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
    str = " $(entry.name) = $(entry.value),"
    if !isempty(entry.doc)
        str *= " ! $(entry.doc)"
    end
    str
end

function format(entries::Entries)
    lines = String[]
    for e in entries
        push!(lines, format(e))
    end
    lines
end

function format(group::OptionGroup{SingleEntries})
    head = group.name |> string |> uppercase
    lines = String[]
    push!(lines, "&$(head)")
    push!(lines, format(group.entries)...)
    push!(lines, " /")
    lines
end

function format(group::OptionGroup{MultipleEntries})
    head = group.name |> string |> uppercase
    lines = String[]
    for entries in group.entries
        push!(lines, "&$(head)")
        push!(lines, format(entries)...)
        push!(lines, " /")
    end
    lines
end

function format(opt::Option)
    lines = String[]
    for group in opt.groups
        push!(lines, format(group)...)
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

function area2outgrid(area::Vector{<:Real}, gridres = 0.01; nested = false)
    outlon0 = area[2]
    outlat0 = area[3]
    Δlon = area[4] - outlon0
    Δlat = area[1] - outlat0
    Δlon, Δlat = round.([Δlon, Δlat], digits = 7)
    (numxgrid, numygrid) = try
        convert(Int, Δlon / gridres), convert(Int, Δlat / gridres)
    catch
        error("gridres must divide area")
    end
    dxout = gridres
    dyout = gridres
    res = Dict(
        :OUTLON0 => outlon0, :OUTLAT0 => outlat0, :NUMXGRID => numxgrid, :NUMYGRID => numygrid, :DXOUT => dxout, :DYOUT => dyout,
    )
    nested ? Dict(
        String(k) * 'N' |> Symbol => v for (k, v) in res
    ) : res
end

function area2outgrid(fpdir::FlexpartDir, gridres::Real; nested = false)
    firstinput = readdir(fpdir[:input], join = true)[1]
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

# function setfromdates!(fpoptions::FlexpartOption, start::DateTime, finish::DateTime)
#     toset = OrderedDict(
#         :IBDATE => Dates.format(start, "yyyymmdd"),
#         :IEDATE => Dates.format(finish, "yyyymmdd"),
#         :IBTIME => Dates.format(start, "HHMMSS"),
#         :IETIME => Dates.format(finish, "HHMMSS"),
#     )
#     merge!(fpoptions["COMMAND"][:command][1], toset)
# end

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