#!/bin/bash
set -e

#
# This script can be used to safely build an image locally,
# without the Laniakea Spark runner, but in the exact same
# environment as if it was executed on the StartOS build
# infrastructure.
#

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

BASEDIR=$(dirname "$(readlink -f "$0")")
SUITE=bullseye
PLATFORM="$1"
if [ -z "$1" ]; then
    PLATFORM="$(uname -m)"
fi
if [ "$PLATFORM" = "x86_64" ] || [ "$PLATFORM" = "x86_64-nonfree" ]; then
	ARCH=amd64
elif [ "$PLATFORM" = "aarch64" ] || [ "$PLATFORM" = "aarch64-nonfree" ] || [ "$PLATFORM" = "raspberrypi" ]; then
	ARCH=arm64
else
	ARCH="$PLATFORM"
fi
VERSION="$(dpkg-deb --fsys-tarfile overlays/deb/embassyos_0.3.x-1_${ARCH}.deb | tar --to-stdout -xvf - ./usr/lib/embassy/VERSION.txt)"
GIT_HASH="$(dpkg-deb --fsys-tarfile overlays/deb/embassyos_0.3.x-1_${ARCH}.deb | tar --to-stdout -xvf - ./usr/lib/embassy/GIT_HASH.txt | head -c 7)"
STARTOS_ENV="$(dpkg-deb --fsys-tarfile overlays/deb/embassyos_0.3.x-1_${ARCH}.deb | tar --to-stdout -xvf - ./usr/lib/embassy/ENVIRONMENT.txt)"
VERSION_FULL="${VERSION}-${GIT_HASH}"
if [ -n "$STARTOS_ENV" ]; then
  VERSION_FULL="$VERSION_FULL~${STARTOS_ENV}"
fi

if [ -z "$DSNAME" ]; then
	DSNAME="$SUITE"
fi

imgbuild_fname="$(mktemp /tmp/exec-mkimage.XXXXXX)"
cat > $imgbuild_fname <<END
#!/bin/sh

export IB_SUITE=${SUITE}
export IB_TARGET_ARCH=${ARCH}
export IB_TARGET_PLATFORM=${PLATFORM}
export VERSION_FULL=${VERSION_FULL}
exec ./build.sh
END

prepare_hash=$(sha1sum ${BASEDIR}/prepare.sh | head -c 7)

mkdir -p ${BASEDIR}/results
set +e
debspawn run \
	-x \
	--allow=read-kmods \
	--cachekey="${SUITE}-${prepare_hash}-mkimage" \
	--init-command="${BASEDIR}/prepare.sh" \
	--build-dir=${BASEDIR} \
	--artifacts-out=${BASEDIR}/results \
	--header="StartOS Image Build" \
	--suite=${SUITE} \
	${DSNAME} \
	${imgbuild_fname}

retval=$?
rm $imgbuild_fname
if [ $retval -ne 0 ]; then
    exit $retval
fi
exit 0
