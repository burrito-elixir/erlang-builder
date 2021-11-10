#!/bin/bash

##########
## Initial Prep

set -e
version=$1

if [ -z "${version}" ]; then
  echo "usage: build_otp OTP_VERSION"
  exit 1
fi

mkdir -p $TMPDIR

##########
## OpenSSL

OpenSSL_VERSION="1.1.1i"
OpenSSL_DIR="$HOME/openssl_prefix"

mkdir -p $OpenSSL_DIR

echo "building OpenSSL $OpenSSL_VERSION"
curl https://www.openssl.org/source/openssl-$OpenSSL_VERSION.tar.gz -O
tar -xzf openssl-$OpenSSL_VERSION.tar.gz
cd openssl-$OpenSSL_VERSION

if [[ $APPLE_SILICON == 1 ]]
then
  CC="clang -target arm64-apple-macos11" ./Configure darwin64-arm64-cc no-shared --prefix="$OpenSSL_DIR" && make depend && make -j && make install
else
  ./config no-shared --prefix="$OpenSSL_DIR" && make depend && make && make install
fi

##########
## OTP

echo "building OTP ${version}"

OTP_BUILD_FLAGS="--disable-parallel-configure --without-jinterface --without-hipe --disable-dynamic-ssl-lib --with-ssl=$OpenSSL_DIR"

# Workaround for drawin compiler flags on some builds of OTP
if [[ $(uname -s) == Darwin ]]
then
    echo "Setting MacOS workaround variables..."
    export EGREP=egrep
    export CC=clang
    export CPP="clang -E"
fi

TMPDIR="${TMPDIR:=tmp}/beamup"
mkdir -p $TMPDIR
echo "cd $TMPDIR"
cd $TMPDIR

export arch="$(uname -sm | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

if [ ! -f otp_src_${version}.tar.gz ]; then
  url=https://github.com/erlang/otp/releases/download/OTP-${version}/otp_src_${version}.tar.gz
  echo "downloading $url" 1>&2
  curl --fail -LO $url 1>&2
fi

if [ ! -d otp_src_${version} ]; then
  mkdir -p otp_src_${version}
  tar xzf otp_src_${version}.tar.gz -C otp_src_${version} --strip-components 1
  cd otp_src_${version}
  export ERL_TOP=$PWD

  # Add target flag and xcomp flags if we are building for Apple Silicon
  if [[ $APPLE_SILICON == 1 ]]
  then
    # we need a bootstrap an install first on our native platform
    echo "We are cross compiling for Apple Silicon, bootstrapping!"
    ./configure --enable-bootstrap-only
    make -j

    # set cross comp flags and compiler target flags
    export CC="$CC -target arm64-apple-macos11"
    export OTP_BUILD_FLAGS="$OTP_BUILD_FLAGS --host=arm64-apple-darwin --build=x86_64-apple-darwin"
    export arch="darwin-arm64"
  fi

  # do the real OTP build
  ./otp_build setup -a $OTP_BUILD_FLAGS 1>&2
  cd ..
fi

##########
## Release archive

cd otp_src_${version}
export ERL_TOP=$PWD
release=$(echo otp-${version}-$arch)

export RELEASE_ROOT=$TMPDIR/${release}
make release -j$(getconf _NPROCESSORS_ONLN) 1>&2

cd $TMPDIR
echo "creating ${TMPDIR}/${release}.tar.gz"
tar czf ${release}.tar.gz ${release}
ls -lah ./
ls -lah ${TMPDIR}
