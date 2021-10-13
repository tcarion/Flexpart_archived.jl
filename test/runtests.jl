using Flexpart
using Test
using Dates

# Flexpart.NCF_OUTPUT
# @show Flexpart.option2dict("outgrid")
# Flexpart.find_ncf()
# # Flexpart.outclear()
# # Flexpart.outinfo()
# Flexpart.outgrid()
# @show Flexpart.conc(9)
# Flexpart.fields(9)
# outgrid = Flexpart.Outgrid(5.009, 50.353, 1111, 593, 0.001, 0.001, [100.0])

# @testset "Flexpart.jl" begin
    ###################################
    ###### TEST FLEXPART DIR ##########
    ###################################
    dirpath = "test/fp_dir_test"
    newdir = Flexpart.create(dirpath)
    fpdir = FlexpartDir(dirpath)
    # pathnam = Flexpart.pathnames(newdir)
    fpdir[:output]
    fpdir[:input] = "/home/tcarion/.julia/dev/Flexpart/test/fe_template/fedir/input"
    fpdir[:input]
    write(fpdir)

    ###################################
    ###### TEST FLEXPART INPUT ########
    ###################################
    inputdir = "test/fp_dir_test/input"
    # av = Flexpart.Available(fpdir)
    # new_av = Flexpart.update(av, "/home/tcarion/.julia/dev/Flexpart/test/fe_template/fedir/input")
    # new_av2 = Flexpart.update(av, DateTime(2021, 8, 8):Dates.Hour(1):DateTime(2021, 8, 9)|>collect, "PREF")
    newav = Flexpart.updated_available(fpdir)
    Flexpart.write(fpdir, newav)

    ###################################
    ###### TEST FLEXPART OPTIONS ######
    ###################################
    fpoptions = FlexpartOptions(dirpath)
    fpoptions["COMMAND"][:command][:ldirect] = 9
    area = [50, 4, 52, 6]
    newv = area2outgrid(area)
    set!(fpoptions["OUTGRID"][:outgrid], newv)
    write(fpoptions, pwd())

    fopt = Flexpart.getnamelists(Flexpart.getdir(fpdir, :options))

    comp = Flexpart.compare(
        "/home/tcarion/.julia/dev/Flexpart/test/fp_dir_test/output/COMMAND.namelist",
        "/home/tcarion/.julia/dev/Flexpart/test/fp_dir_test/output/COMMAND.namelist2")

    # dirs = files[isdir.(files)]
    ###################################
    ###### TEST FLEXPART OUTPUTS ######
    ###################################
    output_files = ncf_files(fpdir)
    fpoutput = FlexpartOutput(output_files[1])
    
    var2d = Flexpart.variables2d(fpoutput)
    vars = Flexpart.variables(fpoutput)
    dims = Flexpart.remdim(fpoutput, "spec001_mr")
    globattr = Flexpart.attrib(fpoutput)
    specattrib = Flexpart.attrib(fpoutput, "spec001_mr")
    adims = Flexpart.alldims(fpoutput, "spec001_mr")

    spec001 = Flexpart.select(fpoutput, "spec001_mr");
    oro = Flexpart.select(fpoutput, "ORO")

    spec001_alltimes = Flexpart.select(fpoutput, "spec001_mr", (time=:, height=1, pointspec=1, nageclass=1))
    spec001_2d_1 = Flexpart.select(fpoutput, "spec001_mr", 
        Dict(:time=>adims[:time][4], :height=>adims[:height][2], :pointspec=>1, :nageclass=>1))

    spec001_2d_2 = Flexpart.select(fpoutput, "spec001_mr", 
        Dict(:time=>adims[:time][7], :height=>adims[:height][2], :pointspec=>1, :nageclass=>1))

    spec001_2d_3 = Flexpart.select(fpoutput, "spec001_mr", 
        Dict(:time=>adims[:time][7], :height=>:, :pointspec=>1, :nageclass=>1))

    seltime = Flexpart.selected(spec001_alltimes)
    sel = Flexpart.selected(spec001_2d)

    dayav_error = Flexpart.daily_average(spec001)
    dayav = Flexpart.daily_average(spec001_alltimes)

    compdim = Flexpart.completedim(spec001_alltimes)

    Flexpart.addable(spec001_2d_1, spec001_2d_2)
    Flexpart.addable(spec001_2d_1, spec001_alltimes)

    added = spec001_2d_1 + spec001_2d_2
    diff = spec001_2d_1 - spec001_2d_2

    Flexpart.write_daily_average(spec001, copy=true)

    
    ###################################
    ###### TEST FLEXEXTRACT ###########
    ###################################
    installpath = "/home/tcarion/flexpart/flex_extract_v7.1.2"
    defaultcontrol = "./test/fe_template/CONTROL_OD.OPER.FC.eta.highres.app"
    fepath = "test/fe_template/fedir"
    pythonpath = "/opt/anaconda3/bin/python3"

    fcontrol = FlexControl(defaultcontrol)
    area = [52.2, 4, 49, 6]
    fcontrol[:REQUEST] = 1
    # set!(fcontrol, Dict(:CLASS => "foo", :ETA => 2))
    set_area!(fcontrol, area)
    set_steps!(fcontrol, DateTime("2021-09-05T00:00:00"), DateTime("2021-09-07T00:00:00"), 1)

    fedir = FlexextractDir(fepath, fcontrol)
    fesource = FeSource(installpath, pythonpath)
    
    cmd = Flexpart.getcmd(fedir, fesource)

    # pip = pipeline(cmd, `sleep 3`, `echo COUCOU`)
    # logf = open("log.log", "w")
    # open(pip) do io
    #     lines = readlines(io, keep=true)
    #     for line in lines
    #         Base.write(logf, line)
    #         flush(logf)
    #     end
    # end
    # close(logf)

    # write(fcontrol, "test/fe_template/fe_output")

    ###################################
    ######## TEST MARSREQUESTS ########
    ###################################
    destmars = "test/fe_template/"
    csvpath = "test/fe_template/²fedir/input/mars_requests.csv"
    tmpdir = "test/tmp"
    requests = MarsRequest(csvpath)
    req = requests[1]
    push!(req.dict, :dqsdqsdq => "dqsdqsdq")
    Flexpart.retrieve(fesource, [req])
    # cmd = Flexpart.retrievecmd(fesource, req, tmpdir)

    open("log.log", "w") do logf
        Flexpart.retrieve(fesource, [req]) do stream
            data = readline(stream, keep=true)
            Base.write(logf, data)
            flush(logf)
        end
    end
    write(destmars, [requests[1]])

    ###################################
    ###### TEST PREPARE FLEXPART ######
    ###################################
    fedir = FlexextractDir(fepath)
    cmd = Flexpart.preparecmd(fedir, fesource)
    run(cmd)

    cmd = Flexpart.preparecmd(FlexextractDir(), fesource)
    Flexpart.prepare(fedir, fesource) do stream
        data = readline(stream, keep=true)
        Base.write(logf, data)
        flush(logf)
    end
    ###### TEST FLEXPART OLD ######
    close(logf)
    Flexpart.relloc(filename)
    Flexpart.start_dt(filename)
    Flexpart.times_dt(filename)
    output1 = Flexpart.FlexpartOutput(filename);
    Flexpart.select!(output1, "spec001_mr");
    output2 = Flexpart.FlexpartOutput(filename);
    @test Flexpart.hasselection(output1) == true
    @test Flexpart.hasselection(output2) == false
    @test Flexpart.hasfield2d(output1) == true

    Flexpart.isspatial(output1)
    Flexpart.isspatial(output2)
    Flexpart.remdim(output1)
    Flexpart.remdim(output2)

    dims = (time=:, height=1, pointspec=1, nageclass=1)
    dims = Dict(:height=>15., :time=>"20200203T080000", :pointspec=>1, :nageclass=>1)
    Flexpart.select!(output1, dims);
    time_av = Flexpart.faverage(output1);
    daily_av, days = Flexpart.daily_average(output1);
    Flexpart.attrib(output1)

    out_daily = Flexpart.write_daily_average(output1)
    Flexpart.select!(out_daily, "daily_av")
    Flexpart.select!(out_daily, (day=:,))
    out_worst = Flexpart.write_worst_day(out_daily)
    Flexpart.alldims(output2)
    Flexpart.close(output1)
    Flexpart.close(output2)

# end
