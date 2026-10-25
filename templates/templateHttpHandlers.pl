:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `SelectHttpHandlers` kbapi query.
%
% Every handler `endpoints_http/4` recognizes, filtered by verb, by
% authentication and by url parts.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {VERBS}            - list of verbs to keep ( get, post, ..., unknown )
%   {AUTHENTICATIONS}  - list of [ authenticated, unauthenticated ] to keep
%   {URL_PARTS}        - `none`, or a list of strings the url must contain
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Output : one JSON list of
%
%   { location, verb, url,
%     def : { kind, name, className },
%     userInputs : [ { kind, location, name } ],
%     auth : null | { name, evidence, headerKey } }
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_class_def/3.
:- dynamic kb_method_of_class/2.
:- dynamic kb_method_has_name/2.
:- dynamic kb_call_method_of_class/3.
:- dynamic kb_class_has_1st_party_super/3.
:- dynamic kb_class_has_3rd_party_super/3.
:- dynamic kb_callable_source_body_length/2.
:- dynamic kb_callable_has_annotation/2.
:- dynamic kb_param_has_annotation/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_const_string/2.
:- dynamic kb_param_has_name/2.
:- dynamic kb_param_i_of_callable/3.
:- dynamic kb_param_has_resolved_type/2.
:- dynamic kb_dataflow_edge/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Verbs = {VERBS},
    Auths = {AUTHENTICATIONS},
    UrlParts = {URL_PARTS},
    Limit = {LIMIT},
    findnsols(Limit, Handler, handler(Verbs, Auths, UrlParts, Handler), Handlers),
    !,
    json_write_dict(current_output, Handlers, [width(0)]),
    nl.

handler(Verbs, Auths, UrlParts, _{ location: Handler, verb: Verb, url: Url, def: Def, userInputs: Inputs, auth: Auth }) :-
    distinct(Handler-Verb-Url, endpoints_http(Handler, Verb, RequestObject, Url)),
    memberchk(Verb, Verbs),
    contains_url_parts(UrlParts, Url),
    auth(Handler, Auth),
    auth_kind(Auth, AuthKind),
    memberchk(AuthKind, Auths),
    def(Handler, Def),
    user_inputs(Handler, RequestObject, Inputs).

contains_url_parts(none, _) :- !.
contains_url_parts(Parts, Url) :- forall(member(Part, Parts), sub_atom(Url, _, _, _, Part)).

auth(Handler, _{ name: Name, evidence: Evidence, headerKey: HeaderKey }) :-
    once(endpoints_http_auth(Handler, Name, AuthEvidence)),
    !,
    evidence(AuthEvidence, Evidence, HeaderKey).
auth(_, null).

evidence(by_header_null_check(HeaderKey), 'ByHeaderNullCheck', HeaderKey).
evidence(by_all_but_one_bad_return, 'ByAllButOneBadReturn', null).

auth_kind(null, unauthenticated) :- !.
auth_kind(_, authenticated).

def(Handler, _{ kind: 'MethodOfClass', name: Name, className: ClassName }) :-
    kb_method_has_name(Handler, Name),
    kb_method_of_class(Handler, Class),
    kb_class_def(Class, ClassName, _),
    !.
def(Handler, _{ kind: 'NamedFunction', name: Name, className: null }) :-
    kb_func_def(Handler, Name, _, _),
    !.
def(_, _{ kind: 'AnonymousFunction', name: null, className: null }).

% spring : user input arrives through annotated params ; the
% request-object slot holds the routing annotation
user_inputs(Handler, Mapping, Inputs) :-
    kb_callable_has_annotation(Handler, Mapping),
    !,
    findall(Index-Input, ( kb_param_i_of_callable(Param, Index, Handler), spring_input(Param, Input) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Inputs).
% servlet : the request param's `getParameter( name )` calls, or the
% request param itself when the handler reads none
user_inputs(Handler, Request, Inputs) :-
    endpoints_http_servlet(Handler, Request),
    !,
    findall(Input, ( kb_called_from(Call, Handler), servlet_input(Call, Input) ), Found),
    (   Found == [] -> Inputs = [ _{ kind: 'RequestObject', location: Request, name: null } ] ; Inputs = Found ).
user_inputs(_, RequestObject, [ _{ kind: 'RequestObject', location: RequestObject, name: null } ]).

servlet_input(Call, _{ kind: 'RequestParam', location: Call, name: Name }) :-
    endpoints_user_input_servlet(Call),
    (   kb_arg_i_for_call(Arg, 0, Call), kb_const_string(Arg, Name) -> true ; Name = '' ).

spring_input(Param, _{ kind: Kind, location: Param, name: Name }) :-
    kb_param_has_annotation(Param, Annotation),
    kb_call_resolved(Annotation, Fqn),
    spring_input_kind(Fqn, Kind),
    !,
    param_name(Param, Name).

spring_input_kind('org.springframework.web.bind.annotation.RequestParam', 'RequestParam').
spring_input_kind('org.springframework.web.bind.annotation.PathVariable', 'PathVariable').
spring_input_kind('org.springframework.web.bind.annotation.RequestBody', 'RequestBody').
spring_input_kind('org.springframework.web.bind.annotation.RequestHeader', 'RequestHeader').
spring_input_kind('org.springframework.web.bind.annotation.CookieValue', 'CookieValue').
spring_input_kind('org.springframework.web.bind.annotation.RequestPart', 'RequestPart').

param_name(Param, Name) :- kb_param_has_name(Param, Name), !.
param_name(_, '').
