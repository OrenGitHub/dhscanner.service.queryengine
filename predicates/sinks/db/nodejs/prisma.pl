:- style_check(-singleton).

% ------------------------------------------------------------------
% Prisma SQL sink catalog.
%
% Prisma is the dominant TypeScript/Node.js ORM; its API splits
% cleanly along the exact axis the `SqlSinkKind` tagged union in
% `dhscanner.packages/dhscanner.kbapi/src/Content.hs` cares about:
%
%   `$queryRawUnsafe` / `$executeRawUnsafe`   -> `SqlRaw`
%     The caller hands Prisma a plain SQL string. Any interpolation
%     is the caller's responsibility; injection risk sits on the
%     caller side.
%
%   `$queryRaw` / `$executeRaw`               -> `SqlRaw`
%     Tagged-template variants. In well-formed TS source the tag
%     makes them parametrise-by-construction, but the KB can't tell
%     the tagged form from the plain-call form of the same callable
%     at the FQN layer (both resolve to the same `PrismaClient`
%     method). We classify these as `SqlRaw` and let the KB-side
%     refinement (presence/absence of a `Prisma.sql`-tagged template
%     at the call site) clear the ones that are actually safe.
%
%   `prisma.<model>.<verb>`                   -> `SqlPreparedStatement`
%     The typesafe model methods (`findMany`, `create`, `update`,
%     `upsert`, `delete`, `aggregate`, ...). Prisma builds the SQL
%     from a typed where/data tree; the user has no textual seam.
%     We enumerate the method names here as a per-model wildcard
%     (the <model> segment is schema-specific per project, so the
%     recognizer binds the method tail rather than the full FQN).
%
% FQN format mirrors the existing Node.js leaf files
% (`sinks/files/nodejs/native.pl` uses `'fs/promises.writeFile'`),
% i.e. the ESM import specifier followed by a dot-separated
% method chain. Importers see `@prisma/client`, so the chain is
% `@prisma/client.PrismaClient.<method>`.
%
% File location follows the per-library-per-language convention
% already used for the other ORMs
% (`sinks/db/php/yii.pl`, `sinks/db/golang/gorm.pl`).
% The two predicates exposed here are consumed by
% `predicates/sinks/api.pl` as the Node.js leaves of
% `sinks_sqli/1` and `sinks_has_prepared_statement_fqn/1`.
% ------------------------------------------------------------------

% ------------------------------------------------------------------
% Raw (injection-risky) sink shapes.
%
% One clause per concrete FQN, matching the one-clause-per-FQN
% convention in `sinks/rce/golang/native.pl`. Adding a new raw
% entry point (Prisma occasionally ships new `$...Raw*` variants)
% is a pure leaf addition here -- no existing consumer needs to
% change.
% ------------------------------------------------------------------
sinks_sqli_nodejs_prisma(Call) :-
    kb_call_resolved(Call, '@prisma/client.PrismaClient.$queryRawUnsafe').

sinks_sqli_nodejs_prisma(Call) :-
    kb_call_resolved(Call, '@prisma/client.PrismaClient.$executeRawUnsafe').

sinks_sqli_nodejs_prisma(Call) :-
    kb_call_resolved(Call, '@prisma/client.PrismaClient.$queryRaw').

sinks_sqli_nodejs_prisma(Call) :-
    kb_call_resolved(Call, '@prisma/client.PrismaClient.$executeRaw').

% ------------------------------------------------------------------
% Prepared-statement (safe-by-construction) sink shapes.
%
% Prisma's typesafe model methods -- `prisma.<model>.findMany`,
% `prisma.<model>.create`, etc. The <model> segment is schema-
% specific per project, so we match on the method tail via
% `kb_fqn_has_suffix/2` rather than enumerating per-schema FQNs.
% If the KB doesn't expose a suffix predicate yet, swap this
% body for a hand-maintained enumeration of
% `@prisma/client.PrismaClient.<Model>.<method>` tuples.
% ------------------------------------------------------------------
sinks_has_prepared_statement_fqn_nodejs_prisma(PreparedStatement) :-
    kb_has_fqn(PreparedStatement, Fqn),
    prisma_prepared_statement_method_fqn(Fqn).

prisma_prepared_statement_method_fqn(Fqn) :- atom_concat('@prisma/client.PrismaClient.', _ModelAndTail, Fqn), prisma_fqn_tail_is_prepared(Fqn).

prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.findUnique',         Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.findUniqueOrThrow',  Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.findFirst',          Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.findFirstOrThrow',   Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.findMany',           Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.create',             Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.createMany',         Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.createManyAndReturn',Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.update',             Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.updateMany',         Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.updateManyAndReturn',Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.upsert',             Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.delete',             Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.deleteMany',         Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.count',              Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.aggregate',          Fqn).
prisma_fqn_tail_is_prepared(Fqn) :- atom_concat(_, '.groupBy',            Fqn).
