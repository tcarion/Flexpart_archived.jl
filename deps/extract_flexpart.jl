using Tar
using Pkg.Artifacts

artifact_toml = "Artifacts.toml"

flexpart_hash = artifact_hash("flexpart", artifact_toml)

tarname = "flexpart_v10.4.tar"
flexpartdirname = "flexpart"
extractname = "flexpart_v10.4_3d7eebf"

rootflexpart = artifact"flexpart"
flexpart_path = joinpath(rootflexpart, flexpartdirname)
tarpath = joinpath(rootflexpart, tarname)

# check if the flexpart dir exists
if !isdir(flexpart_path)
    # check if the .tar file exists
    if !isfile(tarpath)
        error("the artifact has not been download")
        # TODO download artifact
    end
    # extract the .tar file, move it to the artifact folder and remove the .tar file
    tmppath = Tar.extract(tarpath)
    mv(joinpath(tmppath, extractname), flexpart_path)
    rm(tarpath)
end
