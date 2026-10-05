:- style_check(-singleton).
:- discontiguous endpoints_http_get/3.
:- discontiguous endpoints_unauthenticated_http_get/3.

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
        (GetHandler, Request, Url),
        (
            endpoints_unauthenticated_http_get(GetHandler, Request, Url)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(GetHandler, Request, Url)|Tail]) :-
    format("GetHandler(~q)~nRequest(~q)~nUrl(~q)~n~n", [GetHandler, Request, Url]),
    print_matches(Tail).
