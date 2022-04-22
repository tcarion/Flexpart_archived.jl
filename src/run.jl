function getcmd(fpdir::FlexpartDir)
    pn_path = pathnames_path(fpdir)
    `$FLEXPART_EXECUTABLE $pn_path`
end

"""
    $(TYPEDSIGNATURES)

Run Flexpart using the paths of `fpdir`.
"""
function run(fpdir::FlexpartDir{Deterministic}; log = false) 
    if log == false 
        _run_helper(fpdir; f = nothing)
    else
        logpath = joinpath(fpdir[:output], "output.log")
        open(logpath, "w") do logf
            run(fpdir) do io
                log_output(io, logf)
            end
        end
    end
end

run(f::Function, fpdir::FlexpartDir{Deterministic}) = _run_helper(fpdir; f = f)

run(fpdir::FlexpartDir{Ensemble}) = _run_helper(fpdir)

function _run_helper(fpdir::FlexpartDir{Deterministic}; f = nothing)
    # println("The following command will be run : $cmd")
    tempfpdir = FlexpartDir()
    tempfpdir[:options] = fpdir[:options]
    tempfpdir[:output] = fpdir[:output]
    tempfpdir[:input] = fpdir[:input]
    tempfpdir[:available] = fpdir[:available]

    write(tempfpdir)
    cmd = getcmd(tempfpdir)
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

function _run_helper(fpdir::FlexpartDir{Ensemble})
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
            run(tempfpdir) do io
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