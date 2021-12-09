module FpOutput

import Flexpart
using Dates

export
    FlexpartOutput,
    ncf_files,
    getpath,
    deltamesh
mutable struct FlexpartOutput
    filename::String
end
FlexpartOutput(fpdir::Flexpart.FlexpartDir, name::String) = FlexpartOutput(joinpath(Flexpart.getdir(fpdir, :output), name))
FlexpartOutput(path::String, name::String) = FlexpartOutput(Flexpart.FlexpartDir(path), name)
getpath(fpoutput::FlexpartOutput) = fpoutput.filename

function ncf_files(fpdir::Flexpart.FlexpartDir; onlynested=false)
    out_files = readdir(Flexpart.getdir(fpdir, :output))
    f = onlynested ? x -> occursin(".nc", x) && occursin("nest", x) :  x ->  occursin(".nc", x)
    files = filter(f, out_files)
    [joinpath(Flexpart.getdir(fpdir, :output), x) |> abspath for x in files]
end

ncf_files(path::String; onlynested=false) = ncf_files(Flexpart.FlexpartDir(path), onlynested=onlynested)

function deltamesh(lons, lats)
    dxs = lons[2:end] - lons[1:end-1]
    dys = lats[2:end] - lats[1:end-1]

    dx = unique(round.(dxs, digits=5))
    dy = unique(round.(dys, digits=5))

    if (length(dx) != 1) || (length(dy) != 1)
        error("mesh is not uniform")
    end

    dx[1], dy[1]
end

function areamesh(lons, lats)
    min_lon = minimum(lons)
    max_lon = maximum(lons)
    if min_lon > 180 || max_lon > 180
        min_lon -= 360
        max_lon -= 360
    end
    if min_lon < -180 || max_lon < -180
        min_lon += 360
        max_lon += 360
    end
    [maximum(lats), min_lon, minimum(lats), max_lon]
end

function filter_fields(lon, lat, field)
    if size(field) != (length(lon), length(lat)) error("dimension mismatch : size(field) == (length(lon), length(lat))") end
    mask = (!).(isapprox.(0., field))

    mg_lon = lon .* ones(length(lat))'
    mg_lat = lat' .* ones(length(lon))

    return mg_lon[mask], mg_lat[mask], field[mask]
end

function faverage(alltimes::Array{<:Real, 3})

    added = zeros(eltype(alltimes), size(alltimes)[1:2])
    N = length(alltimes[1, 1, :])
    for i=1:N
        added += alltimes[:, :, i]
    end
    
    return added ./ N
end

function daily_average(alltimes::Array{T, 3}, times::Vector) where T
    sdays = split_days(times)
    daily_av = zeros(eltype(alltimes), (size(alltimes)[1:2]..., length(sdays)))
    for (index, day_index) in enumerate(sdays)
        days = alltimes[:, :, day_index];
        daily_av[:, :, index] = faverage(days)
    end
    return daily_av
end


symb2string(d::Dict) = Dict(String(k) => v for (k,v) in d)

function sum_abs(field)
    sum(abs, field)
end

function findworst_day(fields::AbstractArray)
    sums = [sum_abs(f) for f in eachslice(fields, dims=3)]
    _, ind = findmax(sums)
    fields[:, :, ind], ind
end

function worst_day(fields::AbstractArray)
    f, _ = findworst_day(fields)
    f
end

function split_days(times::Vector)
    split = Vector{Vector{Int}}()
    cur_day = Dates.day(times[1]) 
    day_inds = Vector{Int}()
    for (index, time) in enumerate(times)
        day = Dates.day(time)
        if day == cur_day
            push!(day_inds, index)
        else
            push!(split, day_inds)
            day_inds = Vector{Int}()
            push!(day_inds, index)
            cur_day = day
        end
    end
    return split
end

end