using Flexpart
using Test
using Dates

Flexpart.NCF_OUTPUT
@show Flexpart.option2dict("outgrid")
Flexpart.find_ncf()
# Flexpart.outclear()
# Flexpart.outinfo()
Flexpart.outgrid()
@show Flexpart.conc(9)
Flexpart.fields(9)
outgrid = Flexpart.Outgrid(5.009, 50.353, 1111, 593, 0.001, 0.001, [100.0])
@testset "Flexpart.jl" begin
    rel = Release(50, 4, DateTime(2020,1,1), DateTime(2020,1,7))
    @show rel
    @show Flexpart.format(rel)
    out = area2outgrid([50.0, 6.0, 45.5, 4.1], 0.1)
    out = set_heights(out, [12.6])
    @show format(out)
end
