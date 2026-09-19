FROM haskell:9.10.3-bookworm
WORKDIR /queryengine
# Base image bumped from haskell:9.6.7 ( Debian bullseye = oldstable ) to
# haskell:9.10.3-bookworm ( Debian 12 = current stable ) to escape a
# recurring class of CI failure on this step : the bullseye-security
# Fastly CDN edge kept returning 404s for three specific .debs
# ( libxml2 +deb11u10 , libarchive13 +deb11u5 , libicu67 +deb11u1 )
# while the origin still had them. Retrying, single-RUN'ing, and pinning
# to snapshot.debian.org all failed to help because snapshot.debian.org
# is fronted by the same Fastly config and inherited the same negative-
# cache entries for those specific files. Full failure trail :
#   #1 34807171833 libxml2 ( two-RUN split )
#   #2 34928609054 libicu67 ( two-RUN split )
#   #3 35425861021 libxml2 + libarchive13 ( merged into single RUN )
#   #4 35426079838 libxml2 + libarchive13 ( bounded 3x retry loop )
#   #5 35426599093 libxml2 + libarchive13 + libicu67 ( snapshot.debian.org pin )
# Bookworm has an independent apt mirror path with different active
# security update timing, so the specific stale-CDN state above does
# not apply to it.
RUN apt-get update \
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
