FROM haskell:9.6.7
WORKDIR /queryengine
# Merged into a single RUN so apt-get update + install are atomic ( they
# were previously two separate RUN layers, which is a classic Debian
# security-mirror race : the security mirror rotates a .deb out from
# under the metadata that `apt-get update` just pulled, and `install`
# then 404s. Repro'd twice in a week -- see failed CI runs
# 34807171833 ( libxml2 ) + 34928609054 ( libicu67 ) ).
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