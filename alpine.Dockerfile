FROM alpine:3.14.2
ARG version
RUN apk update
RUN apk add gcc automake curl wget make linux-headers musl-dev ncurses-dev autoconf

ENV TMPDIR /tmp/beamup

COPY scripts/build_otp.sh /build_otp.sh
RUN chmod +x /build_otp.sh
RUN sh /build_otp.sh $version
