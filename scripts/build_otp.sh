#!/bin/bash

set -e
version=$1

if [ -z "${version}" ]; then
  echo "usage: build_otp OTP_VERSION"
  exit 1
fi

OpenSSL_VERSION="1.1.1l"
OTP_BUILD_FLAGS="--without-jinterface --without-hipe --with-ssl=./openssl-$OpenSSL_VERSION --disable-dynamic-ssl-lib"

echo "building OpenSSL $OpenSSL_VERSION"
curl https://www.openssl.org/source/openssl-$OpenSSL_VERSION.tar.gz -O && \
    tar -xzf openssl-$OpenSSL_VERSION.tar.gz && \
    cd openssl-$OpenSSL_VERSION && ./config && make depend && make && \
    mkdir -p ./openssl-$OpenSSL_VERSION/lib && \
    cp -r ./openssl-$OpenSSL_VERSION/libc* ./openssl-$OpenSSL_VERSION/lib/ && \
    cp -r ./openssl-$OpenSSL_VERSION/libs* ./openssl-$OpenSSL_VERSION/lib/

echo "building OTP ${version}"

TMPDIR="${TMPDIR:=tmp}/beamup"
mkdir -p $TMPDIR
echo "cd $TMPDIR"
cd $TMPDIR

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
  ./otp_build setup -a $OTP_BUILD_FLAGS 1>&2
  cd ..
fi

cd otp_src_${version}
export ERL_TOP=$PWD
release=$(echo otp-${version}-$(uname -sm | tr '[:upper:]' '[:lower:]' | tr ' ' '-'))

export RELEASE_ROOT=$TMPDIR/${release}
make release -j$(getconf _NPROCESSORS_ONLN) 1>&2

# TODO: disabling for now as it unnecessarily regenerates chunks, we already have them from the
# pre-compiled source!
# make release_docs -j$(getconf _NPROCESSORS_ONLN) DOC_TARGETS="chunks"

cd $TMPDIR
echo "creating ${TMPDIR}/${release}.tar.gz"
tar czf ${release}.tar.gz ${release}
