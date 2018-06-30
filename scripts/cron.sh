#!/bin/bash -xe
# astropy/astropy-benchmarks cron.sh
# License: BSD-3-Clause

# adapted for MDAnalysis
# In cron, first cd to the repo
#  cd /home/microway/MDA/repositories/mdanalysis

# Initially, adapt for c3potato
REPO="${HOME}/MDA/repositories/mdanalysis"
ASV_RUN_DIR="${REPO}/benchmarks"
ASV_CONFIG="${ASV_RUN_DIR}/asv_c3potato.conf.json"
CONDA_BIN="${HOME}/MDA/miniconda3/bin"
CONDA_ENV=benchmark


export PATH="${CONDA_BIN}:${PATH}"
source activate ${CONDA_ENV}

# Make sure to be in ASV_RUN_DIR in case relative paths are used
cd ${ASV_RUN_DIR}


ASV_RESULTS_DIR=`python -c "import os.path, asv; print(os.path.abspath(asv.config.Config.load('${ASV_CONFIG}').results_dir))"`
ASV_BENCHMARK_REPO=`dirname ${ASV_RESULTS_DIR}`

MACHINE=`python -c "from asv.machine import Machine; print(Machine.load('~/.asv-machine.json').machine)"`

echo "asv: "`asv --version`
echo "Machine:        $MACHINE"
echo "repository:     ${REPO}"
echo "ASV config:     ${ASV_CONFIG}"
echo "run directory:  ${ASV_RUN_DIR}"
echo "results_dir:    ${ASV_RESULTS_DIR}"
echo "ASV repository: ${ASV_BENCHMARK_REPO}"

cd ${REPO}

# Get the latest develop branch for the benchmarks
## git clean -fxd
git checkout develop
git pull origin develop

# We now run all benchmarks since the last one run in this benchmarks repository. This assumes
# you have previously run at least ``asv run HEAD^!`` and added the results to the repository
# otherwise running ``asv run NEW`` will run all benchmarks since the start of the project.
# We add || true to make sure that if no commits are run (because there aren't any) things don't
# fail. But asv should have a way to return a zero status code in that case, so we should fix
# that in future. The timeout command is used to make sure that the command finishes before
# the next cron job - the timeout value is in seconds and can be adjusted.


# With our setup on c3potato, run from the MDAnalysis repositorie's benchmark
# directory but store the results elsewhere (in ASV_RESULTS_DIR, as defined in the config file)
cd ${ASV_RUN_DIR}

# On Linux - using 'taskset -c 0 <COMMAND>' ensures that the same core is always used when running the benchmarks.
# (not used here because the machine might try to do other things during benchmarks....)
asv run -e --config ${ASV_CONFIG} NEW || true

# kill after 22h so that it does not interfere with a new run
timeout 22h asv run -e -j 4 --config ${ASV_CONFIG} "release-0.11.0..HEAD --merges" --skip-existing-commits || true

# We split the benchmarks from the results benchmarks are with the main code,
# results are in separate repo.

cd ${ASV_BENCHMARK_REPO}

git add results/$MACHINE
git commit -m "New results from $MACHINE"
git push origin master

asv gh-pages --no-push
git push origin +gh-pages

