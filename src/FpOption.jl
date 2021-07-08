abstract type FpOption end

import Base: write
# import Base: convert

mutable struct Releases_ctrl <: FpOption
    nspec::Int
    specnum_rel::Int
end

mutable struct Command <: FpOption
    ldirect::Int
    ibdate::String
    ibtime::String
    iedate::String
    ietime::String
    loutstep::Int
    loutaver::Int
    loutsample::Int
    itsplit::Int
    lsynctime::Int
    ctl::Float64
    ifine::Int
    iout::Int
    ipout::Int
    lsubgrid::Int
    lconvection::Int
    lagespectra::Int
    ipin::Int
    ioutputforeachrelease::Int
    iflux::Int
    mdomainfill::Int
    ind_source::Int
    ind_receptor::Int
    mquasilag::Int
    nested_output::Int
    linit_cond::Int
    surf_only::Int
    cblflag::Int
    ohfields_path::String
end
Command(ibdate, ibtime, iedate, ietime) = 
    Command(1, ibdate, ibtime, iedate, ietime, 3600, 3600, 600, 99999999, 300, 3.0, 4, 9, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, "\"../../flexin/\"")
Command(start::DateTime, finish::DateTime) = Command(Dates.format(start, "yyyymmdd"), Dates.format(start, "HHMMSS"), Dates.format(finish, "yyyymmdd"), Dates.format(finish, "HHMMSS"))
# function set_limits(command::Command, start::DateTime, finish::DateTime)
#     C
mutable struct Release <: FpOption
    idate1::String
    itime1::String
    idate2::String
    itime2::String
    lon1::Float64
    lon2::Float64
    lat1::Float64
    lat2::Float64
    z1::Float64
    z2::Float64
    zkind::Int
    mass::Float64
    parts::Int
    comment::String
end
Release(lon, lat, start::DateTime, finish::DateTime, z=50, mass=1.0, parts=1000, comment="Release 1") = 
    Release(
        Dates.format(start, "yyyymmdd"),
        Dates.format(start, "HHMMSS"),
        Dates.format(finish, "yyyymmdd"),
        Dates.format(finish, "HHMMSS"),
        lon,
        lon,
        lat,
        lat,
        z,
        z,
        1,
        mass,
        parts,
        comment
    )

mutable struct Outgrid <: FpOption
    outlon0::Float64
    outlat0::Float64
    numxgrid::Int
    numygrid::Int
    dxout::Float64
    dyout::Float64
    outheights::Vector{Float64}
end
Outgrid(outlon0, outlat0, xgrid, ygrid, dxout, dyout) = Outgrid(outlon0, outlat0, xgrid, ygrid, dxout, dyout, [100])

mutable struct OutgridN <: FpOption
    outlon0n::Float64
    outlat0n::Float64
    numxgridn::Int
    numygridn::Int
    dxoutn::Float64
    dyoutn::Float64
end

function write(file::IOStream, option::FpOption)
    for line in format(option) write(file, line*"\n") end
end
function write(file::IOStream, options::Vector{<:FpOption})
    for option in options write(file, option) end
end

function write_options(options::Vector{FpOption}, filepath::String, dest::String="")
    (tmppath, tmpio) = mktemp()

    write(tmpio, options)

    close(tmpio)
    newf = dest=="" ? mv(tmppath, filepath, force=true) : mv(tmppath, joinpath(dest, basename(filepath)), force=true)
    chmod(newf, stat(filepath).mode)
    newf
end
write_options(option::FpOption, filepath::String, dest::String="") = write_options([option], filepath, dest)

function format(option::FpOption)::Vector{String}
    type = typeof(option)
    header = type |> string |> uppercase
    str = ["&$(header)"]
    for fn in fieldnames(type)
        key = uppercase(String(fn))
        field = getfield(option, fn)
        val = field |> typeof <: Vector ? join(field, ",") : field
        push!(str, " $key = $val,")
    end
    push!(str, " /")
    str
end

round_area(area::Vector{Float64}, mult=1) = return [ceil(area[1]*mult)/mult, floor(area[2]*mult)/mult, floor(area[3]*mult)/mult, ceil(area[4]*mult)/mult]

function area2outgrid(area::Vector{Float64}, gridres=0.01)
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
    nx = convert(Int, deltalon/gridres |> round)
    ny = convert(Int, deltalat/gridres |> round)

    Outgrid(outlon0, outlat0, nx, ny, gridres, gridres)
end

Base.convert(::Type{OutgridN}, outgrid::Outgrid) = OutgridN(getfield.(Ref(outgrid), filter(x -> x != :outheights, fieldnames(typeof(outgrid))))...)

function set_heights(outgrid::Outgrid, heights::Vector{Float64})
    outgrid.outheights = heights
    outgrid
end