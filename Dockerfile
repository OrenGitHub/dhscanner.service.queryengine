FROM haskell:9.14.1-bookworm
WORKDIR /queryengine
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
