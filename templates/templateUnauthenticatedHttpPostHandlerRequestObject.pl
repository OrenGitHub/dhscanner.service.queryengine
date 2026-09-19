:- style_check(-singleton).
:- discontiguous utils_http_post_handler_request_object/3.
:- discontiguous utils_unauthenticated_http_post_handler_request_object/3.

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
        (PostHandler, Request, Url),
        (
            utils_unauthenticated_http_post_handler_request_object(PostHandler, Request, Url)
        ),
        Matches
    ),
    print_matches(Matches).

print_matches([]) :- !.
print_matches([(PostHandler, Request, Url)|Tail]) :-
    format("PostHandler(~q)~nRequest(~q)~nUrl(~q)~n~n", [PostHandler, Request, Url]),
    print_matches(Tail).
