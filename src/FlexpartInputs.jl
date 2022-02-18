module FlexpartInputs

using ..Flexpart: FlexpartDir, SimType, Deterministic, Ensemble, dateYY
import ..Flexpart
using Dates
using DocStringExtensions

export FlexpartInput, Available, available, getfpdir, readav, DeterministicInput, EnsembleInput

const FLEXEXTRACT_OUTPUT_REG = r"^([A-Z]*)(\d{8,10})(\.N(\d{3}))?"

abstract type AbstractFlexpartInput{SimType} end

abstract type AbstractInputFile{SimType} end

"""
    DeterministicInput

Object that represents a deterministic input file.

$(TYPEDFIELDS)
"""
struct DeterministicInput <: AbstractInputFile{Deterministic}
    "Time of the input file"
    time::DateTime
    "Filename the input file"
    filename::String
end

"""
    EnsembleInput

Object that represents a ensemble input file.

$(TYPEDFIELDS)
"""
struct EnsembleInput <: AbstractInputFile{Ensemble}
    "Time of the input file"
    time::DateTime
    "Filename the input file"
    filename::String
    "Ensemble member number of the input file"
    member::Int
end
Base.convert(::Type{DeterministicInput}, in::EnsembleInput) = DeterministicInput(in.time, in.filename)

struct InputFiles{T}
    files::Vector{<:AbstractInputFile{T}}
end
getfiles(in::InputFiles) = in.files
Base.show(io::IO, mime::MIME"text/plain", infiles::InputFiles) = show(io, mime, getfiles(infiles))
Base.push!(in::InputFiles{Deterministic}, fields) = push!(getfiles(in), DeterministicInput(fields...))
Base.push!(in::InputFiles{Ensemble}, fields) = push!(getfiles(in), EnsembleInput(fields...))
# Base.size(in::InputFiles) where T = Base.size(in.files)
# Base.getindex(in::InputFiles, i::Int) = Base.getindex(in.files, i)
# function Base.setindex!(in::InputFiles, v, i::Int)
#     Base.setindex(in.files, v, i)
# end
InputFiles{T}() where T = InputFiles{T}(T == Deterministic ? DeterministicInput[] : EnsembleInput[])
# InputFiles{T}() where T = println(InputFiles{Ensemble}(EnsembleInput[]))

# const DeterministicInputs = Vector{DeterministicInput}
# const EnsembleInputs = Vector{EnsembleInput}

struct Available{T}
    header::String
    inputs::InputFiles{T}
end
Available(inputfiles::InputFiles{T}) where T = Available{T}(
    """XXXXXX EMPTY LINES XXXXXXXXX
    XXXXXX EMPTY LINES XXXXXXXX
    YYYYMMDD HHMMSS   name of the file(up to 80 characters)""",
    inputfiles
    )
Available(inputs::Vector{<:AbstractInputFile{T}}) where T = Available(InputFiles{T}(inputs))
function Available{T}(path::String) where T
    Available{T}(_available_helper(path, T)...)
end
Available(fpdir::FlexpartDir{T}) where T = Available{T}(fpdir[:available])
Base.collect(av::Available) = av.inputs.files
Base.filter(f::Function, av::Available{T}) where T = Available{T}(av.header, InputFiles{T}(filter(f, av |> collect)))
Base.show(io::IO, mime::MIME"text/plain", av::Available) = show(io, mime, av.inputs)

function _available_helper(path::String, T::SimType)
    lines = readlines(path)
    header, ioc = _header(lines)
    filelines = isnothing(ioc) ? lines : lines[ioc+1:end]
    filelines = filter(x -> x !== "", filelines)
    inputfiles = InputFiles{T}()

    for l in filelines
        sl = split(l)
        date = DateTime(sl[1]*sl[2], "yyyymmddHHMMSS")
        filename = sl[3]
        m = match(FLEXEXTRACT_OUTPUT_REG, filename)
        toadd = T == Deterministic ? (date, filename) : (date, filename, parse(Int, m.captures[4]))
        push!(inputfiles, toadd)
    end

    header, inputfiles
end

function _header(lines)
    ioc = findfirst(x -> occursin("YYYYMMDD HHMMSS", x), lines)
    headerlines = isnothing(ioc) ? [] : lines[1:ioc[1]]
    return join(headerlines, "\n"), ioc
end

"""
    $(TYPEDSIGNATURES)

Create a FlexpartInput object from reading the files in the `input` directory specified by `fpdir`.
The files are expected to have the standard output format from `flex_extract`: <prefix>YYMMDDHH.N<ENSEMBLE_MEMBER>.
See [this link](https://www.flexpart.eu/flex_extract/Documentation/output.html) for more information.
"""
struct FlexpartInput{T} <: AbstractFlexpartInput{T}
    fpdir::FlexpartDir{T}
    available::Available{T}
end
available(fpinput::FlexpartInput) = fpinput.available
getfpdir(fpinput::FlexpartInput) = fpinput.fpdir
function Base.show(io::IO, mime::MIME"text/plain", fpinput::FlexpartInput)
    show(io, mime, getfpdir(fpinput))

    println("With input files:")
    show(io, mime, available(fpinput) |> collect)
end
Base.collect(fpinput::FlexpartInput) = collect(available(fpinput))

FlexpartInput(fpdir::FlexpartDir) = _fp_input_helper(fpdir)
function Base.filter(f::Function, fpinput::FlexpartInput{T}) where T
    FlexpartInput{T}(getfpdir(fpinput), filter(f::Function, available(fpinput)))
end
# FlexpartInput(fpdir::FlexpartDir{Deterministic}) = _fp_input_helper(fpdir, DETERMINISTIC_FILE_REG, Deterministic)

function _fp_input_helper(fpdir::FlexpartDir{T}) where T
    inputdir = fpdir[:input]
    files = readdir(inputdir)
    # reg = T == Deterministic ? ENSEMBLE_FILE_REG : ENSEMBLE_FILE_REG
    inputfiles = InputFiles{T}()
    for file in files
        m = match(FLEXEXTRACT_OUTPUT_REG, file)
        if !isnothing(m)
            x = m.captures[2]
            m_sep = parse.(Int, [x[1:2], x[3:4], x[5:6], x[7:8]])
            formated_date = DateTime(m_sep...)
            toadd = T == Deterministic ? (dateYY.(formated_date), file) : (dateYY.(formated_date), file, parse(Int, m.captures[4]))
            push!(inputfiles, toadd)
        end
    end
    FlexpartInput{T}(
        fpdir,
        Available(inputfiles)
    )
end

"""
    $(TYPEDSIGNATURES)

Create a FlexpartInput object from reading the `available` file specified by `fpdir`.
"""
readav(fpdir::FlexpartDir)::FlexpartInput = FlexpartInput(fpdir, Available(fpdir))

function Flexpart.write(fpinput::FlexpartInput)
    av = available(fpinput)
    fpdir = getfpdir(fpinput)
    dest = fpdir[:available]

    Flexpart.write(av, dest)
end

function Flexpart.write(available::Available, path::String)
    (tmppath, tmpio) = mktemp()

    for line in format(available) Base.write(tmpio, line*"\n") end

    close(tmpio)
    dest = path

    mv(tmppath, dest, force=true)
end

function format(av::Available)
    strs = [av.header]
    for elem in av |> collect
        str = Dates.format(elem.time, "yyyymmdd")*" "*Dates.format(elem.time, "HHMMSS")*"      "*elem.filename*"      "*"ON DISK"
        push!(strs, str)
    end
    strs
end

end