FROM haskell:9.6.7
WORKDIR /queryengine
# Wrapped in a bounded retry loop over the classic Debian security-mirror
# race : the security mirror rotates a .deb out from under the metadata
# that `apt-get update` just pulled, and `install` then 404s. Previously
# repro'd twice in a week ( 34807171833 = libxml2 , 34928609054 = libicu67 )
# and merged into a single RUN to reduce the race window ; occurrence #3
# hit anyway ( 35425861021 = libxml2 + libarchive13 ) so the single-RUN
# fix was compression, not closure.
#
# Root cause is *content* rotation ( 404 on a specific version string ),
# not a network flake, so `Acquire::Retries` doesn't help ( it retries
# network failures, not stale-metadata 404s ). `--fix-missing` also
# doesn't help : it doesn't retry, it *gives up* on missing packages
# and continues, silently producing a container where swi-prolog-nox
# is unusable because its 404'd deps never got installed.
#
# The proper fix is to re-run `apt-get update` between attempts : each
# fresh update re-fetches metadata, so a version-yank that hit attempt
# N is resolved on attempt N+1 ( the metadata now points at the newer
# still-published version ). 3 attempts x 5s sleep = 15s worst-case
# overhead, negligible against the ~11min end-to-end docker build.
RUN for attempt in 1 2 3; do \
      apt-get update \
        && apt-get install -y --no-install-recommends swi-prolog-nox \
        && rm -rf /var/lib/apt/lists/* \
        && exit 0; \
      echo "attempt $attempt failed (debian-security mirror rotation); retrying in 5s"; \
      sleep 5; \
    done; \
    exit 1
COPY dhscanner.cabal dhscanner.cabal
RUN cabal update
RUN cabal build --only-dependencies
COPY template.pl template.pl
COPY utils.pl utils.pl
COPY templates templates
COPY src src
RUN cabal build
CMD ["cabal", "run"]