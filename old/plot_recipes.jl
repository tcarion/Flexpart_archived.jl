@recipe function f(fpds::FpDataset)
    if fpds.dataset isa Matrix
        attr = attrib(fpds.fpoutput, fpds.varname)
        lons, lats = Flexpart.mesh(fpds.fpoutput)
        sel = selected(fpds)
        title --> "$(attr["name"]) - $(haskey(attr, "long_name") ? attr["long_name"] : nothing) [$(attr["units"])] time = $(sel[:time]) height = $(sel[:height])"
        (lons, lats, fpds.dataset' .|> log10)
    else
        error("The dataset must be 2D")
    end
end
# function plot_filtered_grid(file, timestep)
#     rellon, rellat = relloc(file)
#     lon, lat, conc = filtered_fields(file, timestep)

#     mg_lon = lon .* ones(length(lat))'
#     mg_lat = lat' .* ones(length(lon))

#     scatter(rellon, rellat, markershape=:circle)
#     scatter!(mg_lon, mg_lat, markershape=:x, legend=false)
# end

# function with_pyplot(f::Function)
#     f()
#     fig = gcf()
#     close(fig)
#     return fig
# end

# function plot_contour(file, timestep)
#     lon, lat, conc = fields(file, timestep)

#     lonf, latf, concf = filtered_fields(file, timestep)
#     z0max = maximum(concf)
#     z0min = minimum(concf)

#     with_pyplot() do
#         # p = PyPlot.pcolormesh(lon, lat, conc')
#         p = PyPlot.pcolormesh(lon, lat, conc', shading="nearest", norm=matplotlib[:colors][:LogNorm](vmin=z0min, vmax=z0max), cmap=:jet, vmax=z0max)
#         colorbar(p)
#         gca().set_aspect(1)
#     end
# end

# function heat(file, timestep)
#     lon, lat, conc = filtered_fields(file, timestep)
#     heatmap(lon, lat, conc')
# end