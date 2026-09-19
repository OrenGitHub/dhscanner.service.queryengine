FROM haskell:9.6.7
WORKDIR /queryengine
# Pinned to snapshot.debian.org to close a recurring class of CI failure
# on this step. The failures were originally diagnosed as debian-security
# mirror rotation ( a .deb yanked between `update` and `install` ) and
# fixed once by merging update+install into a single RUN ( occurrences #1
# and #2 : 34807171833 libxml2 , 34928609054 libicu67 ) then again by
# wrapping in a bounded retry loop ( occurrence #3 : 35425861021 libxml2
# + libarchive13 ). Both fixes failed on occurrence #4 ( 35426079838 :
# same libxml2 + libarchive13 ) with all 3 retries hitting the *same*
# 404s on the *same* version strings across a 15s window.
#
# That log excluded rotation : if the security mirror had rotated a .deb
# out between attempts, a fresh `apt-get update` on attempt N+1 would
# have seen new metadata pointing at the successor version. Instead the
# metadata was stable ; the .deb files themselves were missing from the
# Fastly CDN edges ( 146.75.30.132 and 146.75.38.132 ) while presumably
# still present at the security.debian.org origin. Retries against the
# same CDN with the same content gap will never succeed ; the CDN just
# needs time ( minutes to hours ) to resync from origin.
#
# snapshot.debian.org is Debian's official archive of every mirror state
# ever published. Snapshots are immutable per-timestamp mirror states
# served from a single origin ( varnish in Helsinki , not Fastly ), so
# by construction if the metadata at a given timestamp references a
# .deb, that .deb is in the same snapshot. No CDN sync race is possible.
#
# Bump SNAPSHOT manually when a real security update is needed ; between
# bumps this Docker build is fully reproducible byte-for-byte. Snapshot
# service is rate-limited ( ~100 req/min per IP ) but a single build
# fits comfortably in that budget.
#
# `Acquire::Check-Valid-Until=false` is required because snapshot Release
# files have a historical Valid-Until by design ; apt otherwise refuses
# metadata that's older than a week or so.
ARG SNAPSHOT=20260918T000000Z
RUN echo "deb http://snapshot.debian.org/archive/debian/${SNAPSHOT}/ bullseye main" > /etc/apt/sources.list \
 && echo "deb http://snapshot.debian.org/archive/debian-security/${SNAPSHOT}/ bullseye-security main" >> /etc/apt/sources.list \
 && rm -f /etc/apt/sources.list.d/*.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends swi-prolog-nox \
 && rm -rf /var/lib/apt/lists/*
COPY dhscanner.cabal dhscanner.cabal
RUN cabal update
RUN cabal build --only-dependencies
COPY template.pl template.pl
COPY utils.pl utils.pl
COPY templates templates
COPY src src
RUN cabal build
CMD ["cabal", "run"]