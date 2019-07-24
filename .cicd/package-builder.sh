#!/usr/bin/env bash
set -eo pipefail
cd $( dirname "${BASH_SOURCE[0]}" ) # Ensure we're in the .cicd dir
. ./.helpers
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
        execute mkdir -p ~/rpmbuild/BUILD
        execute mkdir -p ~/rpmbuild/BUILDROOT
        execute mkdir -p ~/rpmbuild/RPMS
        execute mkdir -p ~/rpmbuild/SOURCES
        execute mkdir -p ~/rpmbuild/SPECS
        execute mkdir -p ~/rpmbuild/SRPMS
        execute sudo yum install -y rpm-build
    elif [[ $ID == 'amzn' ]]; then
        echo "SKIPPED: We do not generate $NAME packages since they use rpms created from Centos."
        exit 0
    else
        echo 'ERROR: Could not determine which operating system this script is running on!'
        uname
        echo "ID_LIKE=\"$ID_LIKE\""
        cat /etc/os-release
        exit 1
    fi
fi
BASE_COMMIT=$(cat build/programs/nodeos/config.hpp | grep 'version' | awk '{print $5}' | tr -d ';')
BASE_COMMIT="${BASE_COMMIT:2:42}"
echo "Found build against $BASE_COMMIT."
cd build/packages
execute chmod 755 ./*.sh
execute ./generate_package.sh "$PACKAGE_TYPE"
[[ -d x86_64 ]] && cd 'x86_64' # backwards-compatibility with release/1.6.x
execute buildkite-agent artifact upload "./$ARTIFACT"
for A in $(echo $ARTIFACT | tr ';' ' '); do
    if [[ $(ls $A | grep -c '') == 0 ]]; then
        echo "+++ :no_entry: ERROR: Expected artifact \"$A\" not found!"
        pwd
        ls -la
        exit 1
    fi
done