using Pkg.Artifacts
using PyCall
using eccodes_jll
using Emoslib_jll

const PIP_PACKAGES = ["eccodes", "genshi", "numpy", "cdsapi", "ecmwf-api-client"]
const FE_SOURCE_PATH = "flex_extract_v7.1.2"

# Install the python dependencies for flex_extract
# See https://discourse.julialang.org/t/pycall-pre-installing-a-python-package-required-by-a-julia-package/3316/16
sys = pyimport("sys")
subprocess = pyimport("subprocess")
subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "--upgrade", PIP_PACKAGES...])


# Compile the fortran code to produce the calc_etadot binary
rootpath = artifact"flex_extract"

source_path = joinpath(rootpath, FE_SOURCE_PATH)
fortran_source_path = joinpath(source_path, "Source", "Fortran")

install_pyscript = joinpath(source_path, "Source", "Python", "install.py")
original_makefile = joinpath(fortran_source_path, "makefile_local_gfortran")
# makefile_new = cp(original_makefile, joinpath(fortran_source_path, "makefile_new"); force=true)

args = [
    "--target=local",
    "--makefile=makefile_local_gfortran"
]

lines = readlines(original_makefile)
new_lines = String[]
for line in lines
    if occursin("ECCODES_INCLUDE_DIR=", line)
        line = "ECCODES_INCLUDE_DIR="*joinpath(eccodes_jll.artifact_dir, "include")
    end
    push!(new_lines, line)
end

open(joinpath(fortran_source_path, "makefile_new"), "w") do io
    for nline in new_lines 
        write(io, nline*"\n")
    end
end

# setup_local = joinpath(source_path, "setup_local.sh")
run(`$(PyCall.python) $(install_pyscript) $args`)

# artifact_toml = joinpath(@__DIR__, "Artifacts.toml")

# fe_hash = artifact_hash("flex_extract", artifact_toml)

# if fe_hash == nothing || !artifact_exists(fe_hash)
#     # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
#     iris_hash = create_artifact() do artifact_dir
#         # We create the artifact by simply downloading a few files into the new artifact directory
#         iris_url_base = "https://archive.ics.uci.edu/ml/machine-learning-databases/iris"
#         download("$(iris_url_base)/iris.data", joinpath(artifact_dir, "iris.csv"))
#         download("$(iris_url_base)/bezdekIris.data", joinpath(artifact_dir, "bezdekIris.csv"))
#         download("$(iris_url_base)/iris.names", joinpath(artifact_dir, "iris.names"))
#     end

#     # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
#     # just overwrite with the new content-hash.  Unless the source files change, we do not expect
#     # the content hash to change, so this should not cause unnecessary version control churn.
#     bind_artifact!(artifact_toml, "iris", iris_hash)
# end