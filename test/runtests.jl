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
    fppath = "./test/fp_template"
    path = "/home/tcarion/CBRN-dispersion-app/public/flexpart_runs/multheights"
    fpdir = FlexpartDir(path)
    ###################################
    ###### TEST FLEXPART OPTIONS ######
    ###################################
    fpoptions = FlexpartOptions(fppath)
    fpoptions["COMMAND"][:command][:ldirect] = 9
    area = [50, 4, 52, 6]
    newv = area2outgrid(area)
    set!(fpoptions["OUTGRID"][:outgrid], newv)
    write(fpoptions, pwd())

    ###################################
    ###### TEST FLEXPART OUTPUTS ######
    ###################################
    nested_name = ncf_files(fppath, onlynested=true)
    nested_output = FlexpartOutput(nested_name[1])
    Flexpart.select!(nested_output, "spec001_mr");
    Flexpart.select!(nested_output, (time=:, height=1, pointspec=1, nageclass=1));
    out_daily = Flexpart.write_daily_average!(nested_output, copy=false)
    close(nested_output)
    
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
    
    proc = run(fedir, fesource, async = true)
    # write(fcontrol, "test/fe_template/fe_output")

    ###################################
    ######## TEST MARSREQUESTS ########
    ###################################
    destmars = "test/fe_template/"
    csvpath = "test/fe_template/fedir/input/mars_requests.csv"
    requests = MarsRequest(csvpath)
    write(destmars, [requests[1]])





    
    ###### TEST FLEXPART OLD ######
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
