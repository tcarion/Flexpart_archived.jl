# abstract type FpOption end

# import Base: write
# mutable struct Command <: FpOption
#     ldirect::Int
#     ibdate::String
#     ibtime::String
#     iedate::String
#     ietime::String
#     loutstep::Int
#     loutaver::Int
#     loutsample::Int
#     itsplit::Int
#     lsynctime::Int
#     ctl::Float64
#     ifine::Int
#     iout::Int
#     ipout::Int
#     lsubgrid::Int
#     lconvection::Int
#     lagespectra::Int
#     ipin::Int
#     ioutputforeachrelease::Int
#     iflux::Int
#     mdomainfill::Int
#     ind_source::Int
#     ind_receptor::Int
#     mquasilag::Int
#     nested_output::Int
#     linit_cond::Int
#     surf_only::Int
#     cblflag::Int
#     ohfields_path::String
# end
# Command(ibdate, ibtime, iedate, ietime) = 
#     Command(1, ibdate, ibtime, iedate, ietime, 3600, 3600, 600, 99999999, 300, 3.0, 4, 9, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, "\"../../flexin/\"")
# Command(start::DateTime, finish::DateTime) = Command(Dates.format(start, "yyyymmdd"), Dates.format(start, "HHMMSS"), Dates.format(finish, "yyyymmdd"), Dates.format(finish, "HHMMSS"))
# function Command(dir::FlexpartDir)
#     dr = namelist2dict(joinpath(dir.path, "options", "COMMAND"))[:COMMAND]
#     d = Dict(k |> String |> lowercase |> Symbol => v for (k, v) in dr)
#     fn = fieldnames(Command)
#     fd = Dict(key => try
#             parse(stype, d[key])
#         catch
#             d[key]
#         end for (key, stype) in zip(fn, Command.types)
#     )
#     #     fd = Dict{Symbol, Any}()
#     # for (key, i) in enumerate(fn)

#     # end
#     nt = NamedTuple{fn}([fd[key] for key in fn])
#     Command(nt...)
#     # Command(
#     #     d[:ldirect],
#     #     d[:ibdate],
#     #     d[:ibtime],
#     #     d[:iedate],
#     #     d[:ietime],
#     #     d[:loutstep],
#     #     d[:loutaver],
#     #     d[:loutsample],
#     #     d[:itsplit],
#     #     d[:lsynctime],
#     #     d[:ctl],
#     #     d[:ifine],
#     #     d[:iout],
#     #     d[:ipout],
#     #     d[:lsubgrid],
#     #     d[:lconvection],
#     #     d[:lagespectra],
#     #     d[:ipin],
#     #     d[:ioutputforeachrelease],
#     #     d[:iflux],
#     #     d[:mdomainfill],
#     #     d[:ind_source],
#     #     d[:ind_receptor],
#     #     d[:mquasilag],
#     #     d[:nested_output],
#     #     d[:linit_cond],
#     #     d[:surf_only],
#     #     d[:cblflag],
#     #     d[:ohfields_path],
#     # )
# end

# mutable struct Release <: FpOption
#     idate1::String
#     itime1::String
#     idate2::String
#     itime2::String
#     lon1::Float64
#     lon2::Float64
#     lat1::Float64
#     lat2::Float64
#     z1::Float64
#     z2::Float64
#     zkind::Int
#     mass::Float64
#     parts::Int
#     comment::String
# end
# Release(lon, lat, start::DateTime, finish::DateTime, z=50, mass=1.0, parts=1000, comment="Release 1") = 
#     Release(
#         Dates.format(start, "yyyymmdd"),
#         Dates.format(start, "HHMMSS"),
#         Dates.format(finish, "yyyymmdd"),
#         Dates.format(finish, "HHMMSS"),
#         lon,
#         lon,
#         lat,
#         lat,
#         z,
#         z,
#         1,
#         mass,
#         parts,
#         comment
#     )

# mutable struct Releases_ctrl <: FpOption
#     nspec::Int
#     specnum_rel::Int
# end
    
# mutable struct Releases <: FpOption
#     releases_ctrl::Releases_ctrl
#     release::Release
# end
# mutable struct Outgrid <: FpOption
#     outlon0::Float64
#     outlat0::Float64
#     numxgrid::Int
#     numygrid::Int
#     dxout::Float64
#     dyout::Float64
#     outheights::Vector{Float64}
# end
# Outgrid(outlon0, outlat0, xgrid, ygrid, dxout, dyout) = Outgrid(outlon0, outlat0, xgrid, ygrid, dxout, dyout, [100])

# mutable struct OutgridN <: FpOption
#     outlon0n::Float64
#     outlat0n::Float64
#     numxgridn::Int
#     numygridn::Int
#     dxoutn::Float64
#     dyoutn::Float64
# end


# FlexpartOptions(path::String)

# struct FlexpartOptions
#     command::Command
#     releases::Releases
#     outgrid::Outgrid
#     outgridn::OutgridN
# end

const OptionName = Symbol
const OptionFileName = String

const FpOption = OrderedDict{Symbol, Any}

const OptionsGroup = Dict{Symbol, FpOption}

const FileOptions = Dict{OptionFileName, OptionsGroup}

struct FlexpartOptions
    dir::FlexpartDir
    options::FileOptions
end

# const STR_TO_TYPE = Dict(
#     "COMMAND" => Command,
#     "RELEASE" => Release,
#     "RELEASES_CTRL" => Releases_ctrl,
#     "RELEASES" => Releases,
#     "OUTGRID" => Outgrid,
#     "OUTGRIDN" => OutgridN,
# )

const OPTION_FILE_NAMES = ["COMMAND", "RELEASES", "OUTGRID", "OUTGRID_NEST"]

function to_fpoption(path::FlexpartPath, name::OptionFileName)
    dir = FlexpartDir(path)
    name = name |> uppercase
    dr = namelist2dict(joinpath(path, OPTIONS_DIR, name))
    OptionsGroup(Symbol(key) => to_fpoption(dr[key], key) for key in keys(dr))
    # Tuple(fpoption)
end

function to_fpoption(dict_option, option::OptionName)
    option = option |> String |> uppercase |> Symbol
    FpOption(k |> String |> lowercase |> Symbol => v for (k, v) in dict_option)
end

FlexpartOptions(path::FlexpartPath) = FlexpartOptions(
    FlexpartDir(path),
    FileOptions(filename => to_fpoption(path, filename) for filename in OPTION_FILE_NAMES)
    )

Base.getindex(fp::FlexpartOptions, name::OptionFileName) = fp.options[name]

# function to_fpoption(dict_option, option::String)
#     option = option |> uppercase
#     fpoption = STR_TO_TYPE[option]
#     d = Dict(k |> String |> lowercase |> Symbol => v for (k, v) in dict_option)
#     fn = fieldnames(fpoption)
#     fd = Dict(key => try
#             if stype <: Vector
#                 parse.(Float64, split(d[key], ","))
#             else
#                 parse(stype, d[key])
#             end
#         catch
#             d[key]
#         end for (key, stype) in zip(fn, fpoption.types)
#     )
#     nt = NamedTuple{fn}([fd[key] for key in fn])
#     fpoption(nt...)
# end

# function FlexpartOptions(dir::FlexpartDir)
#     FlexpartOptions(
#         to_fpoption(dir, "COMMAND")...,
#         Releases(
#             to_fpoption(dir, "RELEASES")...
#         ),
#         to_fpoption(dir, "OUTGRID")...,
#         to_fpoption(dir, "OUTGRID_NEST")...
#     )
# end
# FlexpartOptions(path::String) = FlexpartOptions(FlexpartDir(path))

# function write(file::IOStream, option::FpOption)
#     for line in format(option) write(file, line*"\n") end
# end
# function write(file::IOStream, options::Vector{<:FpOption})
#     for option in options write(file, option) end
# end

# function write_options(options::Vector{FpOption}, filepath::String, dest::String="")
#     (tmppath, tmpio) = mktemp()

#     write(tmpio, options)

#     close(tmpio)
#     newf = dest=="" ? mv(tmppath, filepath, force=true) : mv(tmppath, joinpath(dest, basename(filepath)), force=true)
#     chmod(newf, stat(filepath).mode)
#     newf
# end
# write_options(option::FpOption, filepath::String, dest::String="") = write_options([option], filepath, dest)

function format(options::OptionsGroup)::Vector{String}
    str = []
    for (oname, fpoption) in options
        header = oname |> string |> uppercase
        str = push!(str, "&$(header)")
        for (k, v) in fpoption
            key = uppercase(String(k))
            # val = v |> typeof <: Vector ? join(field, ",") : field
            push!(str, " $key = $v,")
        end
        push!(str, " /")
    end
    str
end


round_area(area::Vector{<:Real}, mult=1) = return [ceil(area[1]*mult)/mult, floor(area[2]*mult)/mult, floor(area[3]*mult)/mult, ceil(area[4]*mult)/mult]

function area2outgrid(area::Vector{<:Real}, gridres=0.01)
    try 
        convert(Int, log10(gridres))
    catch
        throw(ArgumentError("gridres must be 10^n"))
    end

    mult = 1/gridres
    area = round_area(area, mult)
    outlon0 = area[2]
    outlat0 = area[3]
    deltalon = area[4] - outlon0
    deltalat = area[1] - outlat0
    numxgrid = convert(Int, deltalon/gridres |> round)
    numygrid = convert(Int, deltalat/gridres |> round)
    dxout = gridres
    dyout = gridres

    # var = [:outlon0, :outlat0, :numxgrid, :numygrid, :dxout, :dyout]
    # values = eval.(var)
    # Dict(k=> v for (k, v) in zip(var, values))
    Dict(
        :outlon0 => outlon0, :outlat0 => outlat0, :numxgrid => numxgrid, :numygrid => numygrid, :dxout => dxout, :dyout => dyout,
    )
end

function set!(option::FpOption, newv::Dict{Symbol, <:Any})
    merge!(option, newv)
end

function namelist2dict(filepath)
    options = FpOption[]
    headers = OptionName[]
    count = 0
    f = open(filepath, "r")
    for line in eachline(f)
        if !((m = match(r"\s*(.*?)\s*=\s*(\".*?\"|[^\s,]*)\s*,", line)) |> isnothing) #captures the field name in group 1 and the value in group 2
            push!(options[count], m.captures[1] |> Symbol => m.captures[2])
        elseif !((m = match(r"\&(\w*)", line)) |> isnothing) #captures the name of the header in group 1
            count = count + 1
            push!(options, Dict{Symbol, Any}())
            push!(headers, m.captures[1] |> lowercase |> Symbol)
        end
    end
    close(f)
    OptionsGroup(k => v for (k, v) in zip(headers, options))
end


# Base.convert(::Type{OutgridN}, outgrid::Outgrid) = OutgridN(getfield.(Ref(outgrid), filter(x -> x != :outheights, fieldnames(typeof(outgrid))))...)

# function set_heights(outgrid::Outgrid, heights::Vector{Float64})
#     outgrid.outheights = heights
#     outgrid
# end