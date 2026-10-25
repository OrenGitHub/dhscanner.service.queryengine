:- style_check(-singleton).

:- [ 'predicates/endpoints/python/tornado' ].
:- [ 'predicates/endpoints/nodejs/nextjs' ].
:- [ 'predicates/endpoints/nodejs/express' ].
:- [ 'predicates/endpoints/golang/echo' ].
:- [ 'predicates/endpoints/java/spring' ].
:- [ 'predicates/endpoints/java/servlet' ].

% Framework recognizers below share one entry point per verb, so a KB
% from a language without functions ( eg java : methods only ) must
% still let the other frameworks' clauses run.
:- dynamic kb_func_def/4.
:- dynamic kb_call_method_of_class/3.
:- dynamic kb_call_method_of_untyped_named_param/3.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_class_has_1st_party_super/3.

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
endpoints_user_input(UserInput) :- endpoints_user_input_spring(UserInput).
endpoints_user_input(UserInput) :- endpoints_user_input_servlet(UserInput).

% -----------------------------------------------------------------------------
% endpoints_http( Handler, Verb, RequestObject, Url )
%
% Every recognized handler with its verb ( get / post / put / delete /
% patch ). Handlers whose verb is not known yet ( eg spring
% `@RequestMapping( method = ... )` ) are left out.

endpoints_http(Handler, get, RequestObject, Url) :- endpoints_http_get(Handler, RequestObject, Url).
endpoints_http(Handler, post, RequestObject, Url) :- endpoints_http_post(Handler, RequestObject, Url).
endpoints_http(Handler, put, RequestObject, Url) :- endpoints_http_put(Handler, RequestObject, Url).
endpoints_http(Handler, delete, Mapping, Url) :- endpoints_http_spring(Handler, delete, Url, Mapping).
endpoints_http(Handler, patch, Mapping, Url) :- endpoints_http_spring(Handler, patch, Url, Mapping).

% -----------------------------------------------------------------------------
% endpoints_http_auth( Handler, AuthFuncName, AuthEvidence )
%
% `Handler` calls the authenticating function `AuthFuncName`, recognized
% by `AuthEvidence` : by_header_null_check( HeaderKey ) or
% by_all_but_one_bad_return.

endpoints_http_auth(Handler, AuthFuncName, by_header_null_check(HeaderKey)) :-
    kb_called_from(AuthCall, Handler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_early_return_null_on_missing_request_header_value(AuthFunc, HeaderKey).

endpoints_http_auth(Handler, AuthFuncName, by_all_but_one_bad_return) :-
    kb_called_from(AuthCall, Handler),
    auth_authenticating_function(AuthCall, AuthFuncName, AuthFunc),
    auth_authenticating_function_by_return_values(AuthFunc).
