#!/usr/bin/env bash
set -eo pipefail
if [[ $(uname) == 'Darwin' ]]; then
    echo 'Darwin family detected, building for brew.'
    [[ -z $ARTIFACT ]] && ARTIFACT='*.rb;*.tar.gz'
    PACKAGE_TYPE='brew'
else
    . /etc/os-release
    if [[ "$ID_LIKE" == 'debian' || "$ID" == 'debian' ]]; then
        echo 'Debian family detected, building for dpkg.'
        [[ -z $ARTIFACT ]] && ARTIFACT='*.deb'
        PACKAGE_TYPE='deb'
    elif [[ "$ID_LIKE" == 'rhel fedora' || "$ID" == 'fedora' ]]; then
        echo 'Fedora family detected, building for RPM.'
        [[ -z $ARTIFACT ]] && ARTIFACT='*.rpm'
        PACKAGE_TYPE='rpm'
        mkdir -p ~/rpmbuild/BUILD
        mkdir -p ~/rpmbuild/BUILDROOT
        mkdir -p ~/rpmbuild/RPMS
        mkdir -p ~/rpmbuild/SOURCES
        mkdir -p ~/rpmbuild/SPECS
        mkdir -p ~/rpmbuild/SRPMS
        sudo yum install -y rpm-build
    else
        echo '+++ :no_entry: ERROR: Could not determine which operating system this script is running on!'
        echo '$ uname'
        uname
        echo "ID_LIKE=\"$ID_LIKE\""
        echo '$ cat /etc/os-release'
        cat /etc/os-release
        echo 'Exiting...'
        exit 1
    fi
fi
echo '+++ :package: Starting Package Build'
BASE_COMMIT=$(cat build/programs/nodeos/config.hpp | grep 'version' | awk '{print $5}' | tr -d ';')
BASE_COMMIT="${BASE_COMMIT:2:42}"
echo "Found build against $BASE_COMMIT."
cd build/packages
chmod 755 ./*.sh
./generate_package.sh "$PACKAGE_TYPE"
echo '+++ :arrow_up: Uploading Artifacts'
[[ -d x86_64 ]] && cd 'x86_64' # backwards-compatibility with release/1.6.x
${TRAVIS:-false} || buildkite-agent artifact upload "./$ARTIFACT"
for A in $(echo $ARTIFACT | tr ';' ' '); do
    if [[ $(ls $A | grep -c '') == 0 ]]; then
        echo "+++ :no_entry: ERROR: Expected artifact \"$A\" not found!"
        echo '$ pwd'
        pwd
        echo '$ ls -la'
        ls -la
        exit 1
    fi
done
echo '+++ :white_check_mark: Done.'