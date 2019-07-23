#!/usr/bin/env bash
set -eo pipefail
cd $( dirname "${BASH_SOURCE[0]}" )/.. # Ensure we're in the .cicd dir
. ./.helpers

CPU_CORES=$(getconf _NPROCESSORS_ONLN)
if [[ "$(uname)" == Darwin ]]; then
    echo 'Detected Darwin, building natively.'
    [[ -d eos ]] && cd eos
    [[ ! -d build ]] && mkdir build
    cd build
    echo \$PATH
    ccache -s
    echo '$ cmake ..'
    cmake ..
    echo "$ make -j $CPU_CORES"
    make -j $CPU_CORES
    echo 'Running unit tests.'
    echo "$ ctest -j $CPU_CORES -LE _tests --output-on-failure -T Test"
    ctest -j $CPU_CORES -LE _tests --output-on-failure -T Test # run unit tests
else # linux
    DOCKER_RUN_EXTRAS="-e ENABLE_PARALLEL_TESTS=false"
    execute docker run --rm -v $(pwd):/workdir -v /usr/lib/ccache -v $HOME/.ccache:/opt/.ccache -e CCACHE_DIR=/opt/.ccache -e TRAVIS $DOCKER_RUN_EXTRAS $FULL_TAG
fi