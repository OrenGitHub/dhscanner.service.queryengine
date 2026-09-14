:- style_check(-singleton).
:- discontiguous utils_http_get_handler_request_object/3.
:- discontiguous utils_unauthenticated_http_get_handler_request_object/3.

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).

main :-
    Limit = {LIMIT},
    findnsols(
        Limit,
        (GetHandler, Request, Url),
        (
            utils_unauthenticated_http_get_handler_request_object(GetHandler, Request, Url)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(GetHandler, Request, Url)|Tail]) :-
    format("GetHandler(~q)~nRequest(~q)~nUrl(~q)~n~n", [GetHandler, Request, Url]),
    print_matches(Tail).
