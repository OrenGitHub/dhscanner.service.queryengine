:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `SelectConstStrings` kbapi query.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {REGEX}            - the regex, as a Prolog string
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Output : one JSON list of { location, value } objects.
% ------------------------------------------------------------------

:- dynamic kb_const_string/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Regex = {REGEX},
    Limit = {LIMIT},
    findnsols(
        Limit,
        _{ location: Location, value: Value },
        (
            kb_const_string(Location, Value),
            re_match(Regex, Value, [])
        ),
        Matches
    ),
    !,
    json_write_dict(current_output, Matches, [width(0)]),
    nl.
