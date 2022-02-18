struct FpSource
    bin::String
end

"""
    FpSource([path::String])

The FpSource gives the information about the Flexpart installation. `path` is the path to the FLEXPART binary.
If no `path` is provided, it will be assumed that the `FLEXPART` binary is in the `\$PATH`.
"""
FpSource() = FpSource(DEFAULT_BIN)
getbin(fpsource::FpSource) = fpsource.bin

function runcmd(fpdir::FlexpartDir, fpsource::FpSource)
    fbin = getbin(fpsource)
    pn_path = pathnames_path(fpdir)
    `$fbin $pn_path`
end

"""
    $(TYPEDSIGNATURES)

Run Flexpart using the paths of `fpdir` and the Flexpart installation of `FpSource`.
"""
function run(fpdir::FlexpartDir{Deterministic}, fpsource::FpSource; log = false) 
    if log == false 
        _run_helper(fpdir, fpsource; f = nothing)
    else
        logpath = joinpath(fpdir[:output], "output.log")
        open(logpath, "w") do logf
            run(fpdir, fpsource) do io
                log_output(io, logf)
            end
        end
    end
end

run(f::Function, fpdir::FlexpartDir{Deterministic}, fpsource::FpSource) = _run_helper(fpdir, fpsource; f = f)

run(fpdir::FlexpartDir{Ensemble}, fpsource::FpSource) = _run_helper(fpdir, fpsource)

function _run_helper(fpdir::FlexpartDir{Deterministic}, fpsource::FpSource; f = nothing)
    # println("The following command will be run : $cmd")
    tempfpdir = FlexpartDir()
    tempfpdir[:options] = fpdir[:options]
    tempfpdir[:output] = fpdir[:output]
    tempfpdir[:input] = fpdir[:input]
    tempfpdir[:available] = fpdir[:available]

    write(tempfpdir)
    cmd = runcmd(tempfpdir, fpsource)
    println("Will run Flexpart with following pathnames: ")
    println(tempfpdir.pathnames)
    if isnothing(f)
        Base.run(cmd)
    else
        pipe = Pipe()
        @async while true
            f(pipe)
        end

        Base.run(pipeline(cmd, stdout=pipe, stderr=pipe))
    end
end

function _run_helper(fpdir::FlexpartDir{Ensemble}, fpsource)
    av = readav(fpdir) |> available
    inputs = av |> collect
    members = [x.member for x in inputs] |> unique 
    sep_inputs = [filter(x -> x.member==i, inputs) for i in members]

    for realization in sep_inputs
        imember = realization[1].member
        tempfpdir = FlexpartDir()
        memb_out_path = joinpath(fpdir[:output], "member$(imember)")
        mkdir(memb_out_path)
        tempfpdir[:options] = fpdir[:options]
        tempfpdir[:output] = memb_out_path
        tempfpdir[:input] = fpdir[:input]

        det_inputs = convert.(DeterministicInput, realization)
        real_av = Available(det_inputs)
        fpinput = FlexpartInput(tempfpdir, real_av)
        write(fpinput)
        writeabs(tempfpdir)
        
        log_path = joinpath(getpath(fpdir), "member$(imember).log")
        @async open(log_path, "w") do logf
            run(tempfpdir, fpsource) do io
                # line = readline(io, keep=true)
                # Base.write(logf, line)
                # flush(logf)
                log_output(io, logf)
            end
        end 
    end
    # for i in 0:nmember-1
    #     push!(sep_inputs, filter(x -> x.member==i, inputs))
    # end
end

function log_output(io::IO, fileio::IO)
    line = readline(io, keep=true)
    Base.write(fileio, line)
    flush(fileio)
end