module FlexpartOutputs

using Flexpart: FlexpartDir, SimType, Deterministic, Ensemble
using Dates
using DocStringExtensions

export
    AbstractOutputFile,
    OutputFiles,
    DeterministicOutput,
    EnsembleOutput,
    outputpath,
    ncf_files,
    getpath,
    deltamesh


abstract type AbstractOutputFile{SimType} end
Base.convert(::Type{<:AbstractString}, output::AbstractOutputFile) = output.name
"""
    DeterministicInput

Object that represents a deterministic output file.

$(TYPEDFIELDS)
"""
struct DeterministicOutput <: AbstractOutputFile{Deterministic}
    "Name of the output file"
    name::String
end

"""
    EnsembleInput

Object that represents a ensemble output file.

$(TYPEDFIELDS)
"""
struct EnsembleOutput <: AbstractOutputFile{Ensemble}
    "Name of the output file"
    name::String
    "Ensemble member number"
    member::Int
end

struct OutputFiles{T}
    # struct OutputFiles{T} <: AbstractVector{AbstractOutputFile{T}}
    files::Vector{<:AbstractOutputFile{T}}
end
OutputFiles(fpdir::FlexpartDir{T}) where T = OutputFiles{T}(fpdir[:output])
Base.collect(outfiles::OutputFiles) = collect(outfiles.files)
Base.filter(f::Function, outfiles::OutputFiles{T}) where T = OutputFiles{T}(filter(f, outfiles |> collect))
Base.getindex(outfiles::OutputFiles, i::Int) = getindex(outfiles |> collect, i)
Base.iterate(outfiles::OutputFiles, state) = iterate(outfiles.files, state)
Base.iterate(outfiles::OutputFiles) = iterate(outfiles.files)
Base.length(outfiles::OutputFiles) = length(outfiles.files)

function OutputFiles{Deterministic}(path::String)
    files = readdir(path, join = true)
    ncfiles = filter(x -> occursin(".nc", x), files)
    outfiles = [DeterministicOutput(f) for f in ncfiles]
    OutputFiles{Deterministic}(outfiles)
end

function OutputFiles{Ensemble}(path::String)
    files = readdir(path, join = true)
    outfiles = EnsembleOutput[]
    for file in files
        m = match(r"member(\d*)", file)
        number = parse(Int, m.captures[1])
        ncfiles = filter( x -> occursin(".nc", x), joinpath(path, file) |> readdir )
        for ncfile in ncfiles
            push!(outfiles, EnsembleOutput(joinpath(file, ncfile), number))
        end
        # push!(outfiles, EnsembleOutput())
    end
    OutputFiles{Ensemble}(outfiles)
end

# struct FlexpartOutput{T}
#     fpdir::FlexpartDir{T}
#     outfiles::OutputFiles{T}
# end
# FlexpartOutput(fpdir::FlexpartDir) = FlexpartOutput(fpdir, OutputFiles(fpdir))
# Base.collect(fpoutput::FlexpartOutput) = collect(fpoutput.outfiles)
# Base.filter(f::Function, fpoutput::FlexpartOutput) = FlexpartOutput(fpoutput.fpdir, filter(f, fpoutput.outfiles))
# function outputpath(fpoutput::FlexpartOutput)
#     fppath = fpoutput.fpdir[:output]
#     [joinpath(fppath, x.name) for x in fpoutput |> collect]
# end


# function ncf_files(fpdir::FlexpartDir; onlynested=false)
#     out_files = readdir(fpdir[:output])
#     f = onlynested ? x -> occursin(".nc", x) && occursin("nest", x) :  x ->  occursin(".nc", x)
#     files = filter(f, out_files)
#     [joinpath(fpdir[:output], x) |> abspath for x in files]
# end

# ncf_files(path::String; onlynested=false) = ncf_files(FlexpartDir(path), onlynested=onlynested)

# function mean(fpoutput::FlexpartOutput{Ensemble})

# end

# function filter_fields(lon, lat, field)
#     if size(field) != (length(lon), length(lat)) error("dimension mismatch : size(field) == (length(lon), length(lat))") end
#     mask = (!).(isapprox.(0., field))

#     mg_lon = lon .* ones(length(lat))'
#     mg_lat = lat' .* ones(length(lon))

#     return mg_lon[mask], mg_lat[mask], field[mask]
# end

# function faverage(alltimes::Array{<:Real, 3})
#     added = zeros(eltype(alltimes), size(alltimes)[1:2])
#     N = length(alltimes[1, 1, :])
#     for i=1:N
#         added += alltimes[:, :, i]
#     end
    
#     return added ./ N
# end

# function daily_average(alltimes::Array{T, 3}, times::Vector) where T
#     sdays = split_days(times)
#     daily_av = zeros(eltype(alltimes), (size(alltimes)[1:2]..., length(sdays)))
#     for (index, day_index) in enumerate(sdays)
#         days = alltimes[:, :, day_index];
#         daily_av[:, :, index] = faverage(days)
#     end
#     return daily_av
# end


# symb2string(d::Dict) = Dict(String(k) => v for (k,v) in d)

# function sum_abs(field)
#     sum(abs, field)
# end

# function findworst_day(fields::AbstractArray)
#     sums = [sum_abs(f) for f in eachslice(fields, dims=3)]
#     _, ind = findmax(sums)
#     fields[:, :, ind], ind
# end

# function worst_day(fields::AbstractArray)
#     f, _ = findworst_day(fields)
#     f
# end

# function split_days(times::Vector)
#     split = Vector{Vector{Int}}()
#     cur_day = Dates.day(times[1]) 
#     day_inds = Vector{Int}()
#     for (index, time) in enumerate(times)
#         day = Dates.day(time)
#         if day == cur_day
#             push!(day_inds, index)
#         else
#             push!(split, day_inds)
#             day_inds = Vector{Int}()
#             push!(day_inds, index)
#             cur_day = day
#         end
#     end
#     return split
# end

end