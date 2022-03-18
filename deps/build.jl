using Pkg.Artifacts
using PyCall

const PIP_PACKAGES = ["eccodes", "genshi", "numpy", "cdsapi", "ecmwf-api-client"]
const FE_SOURCE_PATH = "flex_extract_v7.1.2"

# Install the python dependencies for flex_extract
# See https://discourse.julialang.org/t/pycall-pre-installing-a-python-package-required-by-a-julia-package/3316/16
sys = pyimport("sys")
subprocess = pyimport("subprocess")
subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "--upgrade", PIP_PACKAGES...])


rootpath = artifact"flex_extract"

source_path = joinpath(rootpath, FE_SOURCE_PATH)
fortran_source_path = joinpath(source_path, "Source", "Fortran")


# run(`$(PyCall.python) $(install_pyscript) $args`)