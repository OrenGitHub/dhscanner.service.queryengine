:- style_check(-singleton).
:- discontiguous utils_http_put_handler_request_object/3.
:- discontiguous utils_authenticated_http_put_handler_request_object/5.

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
            utils_authenticated_http_put_handler_request_object(PutHandler, Request, Url, AuthFuncName, AuthEvidence)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(PutHandler, Request, Url, AuthFuncName, AuthEvidence)|Tail]) :-
    format("PutHandler(~q)~nRequest(~q)~nUrl(~q)~nAuthFuncName(~q)~nAuthEvidence(~q)~n~n",
           [PutHandler, Request, Url, AuthFuncName, AuthEvidence]),
    print_matches(Tail).
