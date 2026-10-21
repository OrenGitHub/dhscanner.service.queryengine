:- style_check(-singleton).

:- [ 'predicates/endpoints/python/tornado' ].
:- [ 'predicates/endpoints/nodejs/nextjs' ].
:- [ 'predicates/endpoints/nodejs/express' ].
:- [ 'predicates/endpoints/golang/echo' ].
:- [ 'predicates/endpoints/java/spring' ].

% Framework recognizers below share one entry point per verb, so a KB
% from a language without functions ( eg java : methods only ) must
% still let the other frameworks' clauses run.
:- dynamic kb_func_def/4.

endpoints_http_get(GetHandler, RequestObject, Url) :-
    endpoints_http_get_nextjs(GetHandler, RequestObject, Url).
endpoints_http_get(GetHandler, RequestObject, Url) :-
    endpoints_http_get_spring(GetHandler, RequestObject, Url).

endpoints_http_post(PostHandler, RequestObject, Url) :-
    endpoints_http_post_nextjs(PostHandler, RequestObject, Url).
endpoints_http_post(PostHandler, RequestObject, Url) :-
    endpoints_http_post_spring(PostHandler, RequestObject, Url).

endpoints_http_put(PutHandler, RequestObject, Url) :-
    endpoints_http_put_nextjs(PutHandler, RequestObject, Url).
endpoints_http_put(PutHandler, RequestObject, Url) :-
    endpoints_http_put_spring(PutHandler, RequestObject, Url).

endpoints_user_input(UserInput) :- endpoints_user_input_tornado(UserInput).
endpoints_user_input(UserInput) :- endpoints_user_input_nextjs(UserInput).
endpoints_user_input(UserInput) :- endpoints_user_input_express(UserInput).
endpoints_user_input(UserInput) :- endpoints_user_input_echo(UserInput).

endpoints_authenticated_http_get(GetHandler, RequestObject, Url, AuthFuncName, by_header_null_check(HeaderKey)) :-
    endpoints_http_get(GetHandler, RequestObject, Url),
    kb_called_from(AuthCall, GetHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_early_return_null_on_missing_request_header_value(AuthFunc, HeaderKey).

endpoints_authenticated_http_get(GetHandler, RequestObject, Url, AuthFuncName, by_all_but_one_bad_return) :-
    endpoints_http_get(GetHandler, RequestObject, Url),
    kb_called_from(AuthCall, GetHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_authenticating_function_by_return_values(AuthFunc).

endpoints_authenticated_http_post(PostHandler, RequestObject, Url, AuthFuncName, by_header_null_check(HeaderKey)) :-
    endpoints_http_post(PostHandler, RequestObject, Url),
    kb_called_from(AuthCall, PostHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_early_return_null_on_missing_request_header_value(AuthFunc, HeaderKey).

endpoints_authenticated_http_post(PostHandler, RequestObject, Url, AuthFuncName, by_all_but_one_bad_return) :-
    endpoints_http_post(PostHandler, RequestObject, Url),
    kb_called_from(AuthCall, PostHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_authenticating_function_by_return_values(AuthFunc).

endpoints_authenticated_http_put(PutHandler, RequestObject, Url, AuthFuncName, by_header_null_check(HeaderKey)) :-
    endpoints_http_put(PutHandler, RequestObject, Url),
    kb_called_from(AuthCall, PutHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_early_return_null_on_missing_request_header_value(AuthFunc, HeaderKey).

endpoints_authenticated_http_put(PutHandler, RequestObject, Url, AuthFuncName, by_all_but_one_bad_return) :-
    endpoints_http_put(PutHandler, RequestObject, Url),
    kb_called_from(AuthCall, PutHandler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_authenticating_function_by_return_values(AuthFunc).

endpoints_unauthenticated_http_get(GetHandler, RequestObject, Url) :-
    endpoints_http_get(GetHandler, RequestObject, Url),
    \+ (
        kb_called_from(AuthCall, GetHandler),
        auth_authenticating_function(AuthCall, _, _)
    ).

endpoints_unauthenticated_http_post(PostHandler, RequestObject, Url) :-
    endpoints_http_post(PostHandler, RequestObject, Url),
    \+ (
        kb_called_from(AuthCall, PostHandler),
        auth_authenticating_function(AuthCall, _, _)
    ).

endpoints_unauthenticated_http_put(PutHandler, RequestObject, Url) :-
    endpoints_http_put(PutHandler, RequestObject, Url),
    \+ (
        kb_called_from(AuthCall, PutHandler),
        auth_authenticating_function(AuthCall, _, _)
    ).
