:- style_check(-singleton).
:- discontiguous utils_http_post_handler_request_object/3.
:- discontiguous utils_authenticated_http_post_handler_request_object/5.

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
        (PostHandler, Request, Url, AuthFuncName, AuthEvidence),
        (
            utils_authenticated_http_post_handler_request_object(PostHandler, Request, Url, AuthFuncName, AuthEvidence)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(PostHandler, Request, Url, AuthFuncName, AuthEvidence)|Tail]) :-
    format("PostHandler(~q)~nRequest(~q)~nUrl(~q)~nAuthFuncName(~q)~nAuthEvidence(~q)~n~n",
           [PostHandler, Request, Url, AuthFuncName, AuthEvidence]),
    print_matches(Tail).
