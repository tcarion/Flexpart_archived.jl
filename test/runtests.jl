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
@testset "Flexpart.jl" begin
    filename = "/home/tcarion/rocourt_project/results/188899-0201-0301_2e6/grid_conc_20200201000000_nest.nc"
    filename2 = "/home/tcarion/rocourt_project/results/188898-0101_0201_2e6/grid_conc_20200101000000_nest.nc"
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

end
