:- style_check(-singleton).
:- discontiguous endpoints_http_put/3.
:- discontiguous endpoints_authenticated_http_put/5.

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_callable_source_body_length/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).

main :-
    Limit = {LIMIT},
    findnsols(
        Limit,
        (PutHandler, Request, Url, AuthFuncName, AuthEvidence),
        (
            endpoints_authenticated_http_put(PutHandler, Request, Url, AuthFuncName, AuthEvidence)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(PutHandler, Request, Url, AuthFuncName, AuthEvidence)|Tail]) :-
    format("PutHandler(~q)~nRequest(~q)~nUrl(~q)~nAuthFuncName(~q)~nAuthEvidence(~q)~n~n",
           [PutHandler, Request, Url, AuthFuncName, AuthEvidence]),
    print_matches(Tail).
