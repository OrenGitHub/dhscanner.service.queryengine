:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Spring ( spring-web ) HTTP endpoint recognizers.
%
% Spring routing lives entirely in annotations. The KB carries an
% annotation as a plain location : `kb_callable_has_annotation/2` and
% `kb_class_has_annotation/2` point at it, and the annotation itself is
% lowered as a call at that same location, so its fqn comes from
% `kb_call_resolved/2` and its arguments from `kb_arg_i_for_call/3`.
%
% A handler's effective annotations are its own plus those of its
% hosting class ( `kb_method_of_class/2` ). That is how the class-level
% `@RequestMapping( "/api/..." )` url prefix reaches the method-level
% `@GetMapping( "/x" )` path.
%
% Not every KB carries these facts ( non-java KBs ), so declare them
% here to keep calls to them failing quietly rather than raising.

:- dynamic kb_callable_has_annotation/2.
:- dynamic kb_class_has_annotation/2.
:- dynamic kb_method_of_class/2.
:- dynamic kb_keyword_arg_for_call/3.
:- dynamic kb_param_has_annotation/2.
:- dynamic kb_field_read_resolved/2.

% -----------------------------------------------------------------------------
% endpoints_http_get_spring( GetHandler, Mapping, Url )
% endpoints_http_post_spring( PostHandler, Mapping, Url )
% endpoints_http_put_spring( PutHandler, Mapping, Url )
%
% Spring handlers have no single request object ( user input arrives
% through `@RequestParam` / `@PathVariable` / `@RequestBody` params ),
% so the request-object slot carries the routing annotation instead :
% a stable location that pins down which declaration made this method
% an endpoint.

endpoints_http_get_spring(GetHandler, Mapping, Url) :-
    endpoints_http_spring(GetHandler, get, Url, Mapping).

endpoints_http_post_spring(PostHandler, Mapping, Url) :-
    endpoints_http_spring(PostHandler, post, Url, Mapping).

endpoints_http_put_spring(PutHandler, Mapping, Url) :-
    endpoints_http_spring(PutHandler, put, Url, Mapping).

% -----------------------------------------------------------------------------
% endpoints_http_spring( Handler, Verb, Url, Mapping )
%
% `Handler` is a method annotated with a spring-web mapping annotation
% `Mapping`. `Verb` is one of get / post / put / delete / patch, or
% `unresolved` for a `@RequestMapping` ( see
% `endpoints_mapping_verb_spring/3` ). `Url` is the hosting class
% prefix followed by the method path.

endpoints_http_spring(Handler, Verb, Url, Mapping) :-
    kb_callable_has_annotation(Handler, Mapping),
    kb_call_resolved(Mapping, Fqn),
    endpoints_mapping_verb_spring(Mapping, Fqn, Verb),
    endpoints_class_prefix_spring(Handler, Prefix),
    endpoints_mapping_path_spring(Mapping, Path),
    endpoints_join_paths_spring(Prefix, Path, Url).

% -----------------------------------------------------------------------------
% endpoints_join_paths_spring( Prefix, Path, Url )
%
% Spring joins class and method paths with exactly one '/' between them :
%   "/api/x"  + "content"  --> /api/x/content
%   "/api/x/" + "**"       --> /api/x/**
%   "/api/x/" + "/y"       --> /api/x/y

endpoints_join_paths_spring(Prefix, '', Prefix) :- !.
endpoints_join_paths_spring(Prefix, Path, Url) :-
    sub_atom(Prefix, _, 1, 0, '/'),
    sub_atom(Path, 0, 1, _, '/'),
    !,
    sub_atom(Path, 1, _, 0, Rest),
    atom_concat(Prefix, Rest, Url).
endpoints_join_paths_spring(Prefix, Path, Url) :-
    ( sub_atom(Prefix, _, 1, 0, '/') ; sub_atom(Path, 0, 1, _, '/') ),
    !,
    atom_concat(Prefix, Path, Url).
endpoints_join_paths_spring(Prefix, Path, Url) :-
    atomic_list_concat([Prefix, '/', Path], Url).

% -----------------------------------------------------------------------------
% endpoints_effective_annotation_spring( Handler, Annotation, Fqn )
%
% Every annotation in effect on `Handler` : its own, then its hosting
% class's. Shared entry point for anything that reads method + class
% annotations together ( routing, `@PreAuthorize`, ... ).

endpoints_effective_annotation_spring(Handler, Annotation, Fqn) :-
    kb_callable_has_annotation(Handler, Annotation),
    kb_call_resolved(Annotation, Fqn).

endpoints_effective_annotation_spring(Handler, Annotation, Fqn) :-
    kb_method_of_class(Handler, Class),
    kb_class_has_annotation(Class, Annotation),
    kb_call_resolved(Annotation, Fqn).

% -----------------------------------------------------------------------------
% endpoints_mapping_verb_spring( Mapping, Fqn, Verb )
%
% The composed `@XxxMapping` annotations fix the verb by name.
%
% `@RequestMapping` carries it in `method = RequestMethod.X` : the
% `RequestMethod.X` field read resolves through `kb_field_read_resolved/2`
% ( see `endpoints_request_mapping_verb_spring/2` ).

endpoints_mapping_verb_spring(_, 'org.springframework.web.bind.annotation.GetMapping', get).
endpoints_mapping_verb_spring(_, 'org.springframework.web.bind.annotation.PostMapping', post).
endpoints_mapping_verb_spring(_, 'org.springframework.web.bind.annotation.PutMapping', put).
endpoints_mapping_verb_spring(_, 'org.springframework.web.bind.annotation.DeleteMapping', delete).
endpoints_mapping_verb_spring(_, 'org.springframework.web.bind.annotation.PatchMapping', patch).
endpoints_mapping_verb_spring(Mapping, 'org.springframework.web.bind.annotation.RequestMapping', Verb) :-
    endpoints_request_mapping_verb_spring(Mapping, Verb).

% -----------------------------------------------------------------------------
% endpoints_request_mapping_verb_spring( Mapping, Verb )
%
%   @RequestMapping( method = RequestMethod.GET )   --> get
%   @RequestMapping( "/x" )                         --> unresolved
%
% A `@RequestMapping` without a resolvable `method = RequestMethod.X`
% matches every verb in spring. Such handlers are reported with
% `unresolved` rather than guessed.

endpoints_request_mapping_verb_spring(Mapping, Verb) :-
    endpoints_request_method_spring(Mapping, Verb).
endpoints_request_mapping_verb_spring(Mapping, unresolved) :-
    \+ endpoints_request_method_spring(Mapping, _).

endpoints_request_method_spring(Mapping, Verb) :-
    kb_keyword_arg_for_call(method, Arg, Mapping),
    kb_field_read_resolved(Arg, Fqn),
    endpoints_request_method_verb_spring(Fqn, Verb).

endpoints_request_method_verb_spring('org.springframework.web.bind.annotation.RequestMethod.GET', get).
endpoints_request_method_verb_spring('org.springframework.web.bind.annotation.RequestMethod.POST', post).
endpoints_request_method_verb_spring('org.springframework.web.bind.annotation.RequestMethod.PUT', put).
endpoints_request_method_verb_spring('org.springframework.web.bind.annotation.RequestMethod.DELETE', delete).
endpoints_request_method_verb_spring('org.springframework.web.bind.annotation.RequestMethod.PATCH', patch).

% -----------------------------------------------------------------------------
% endpoints_class_prefix_spring( Handler, Prefix )
%
% Path of the class-level `@RequestMapping` on the handler's hosting
% class, or '' when there is none.

endpoints_class_prefix_spring(Handler, Prefix) :-
    kb_method_of_class(Handler, Class),
    kb_class_has_annotation(Class, Mapping),
    kb_call_resolved(Mapping, 'org.springframework.web.bind.annotation.RequestMapping'),
    endpoints_mapping_path_spring(Mapping, Prefix),
    !.
endpoints_class_prefix_spring(_, '').

% -----------------------------------------------------------------------------
% endpoints_mapping_path_spring( Mapping, Path )
%
% The path a mapping annotation declares :
%
%   @GetMapping( "/x" )                   --> '/x'
%   @GetMapping( value = "/x" )           --> '/x'
%   @GetMapping( path = "/x" )            --> '/x'
%   @GetMapping                           --> ''
%   @GetMapping( produces = "..." )       --> ''
%   anything else                         --> '{?}'
%
% `anything else` covers paths built from constants
% ( "/api/" + Rest.CATEGORY ). '{?}' keeps the endpoint visible while
% flagging the part of the url we could not recover.
%
% Keyword args keep their positional index too, so the positional
% clause skips them : `produces = "..."` in slot 0 is not a path.

endpoints_mapping_path_spring(Mapping, Path) :-
    endpoints_mapping_path_arg_spring(Mapping, Arg),
    kb_const_string(Arg, Path),
    !.
endpoints_mapping_path_spring(Mapping, '') :-
    \+ endpoints_mapping_path_arg_spring(Mapping, _),
    !.
endpoints_mapping_path_spring(_, '{?}').

endpoints_mapping_path_arg_spring(Mapping, Arg) :-
    kb_keyword_arg_for_call(value, Arg, Mapping).
endpoints_mapping_path_arg_spring(Mapping, Arg) :-
    kb_keyword_arg_for_call(path, Arg, Mapping).
endpoints_mapping_path_arg_spring(Mapping, Arg) :-
    kb_arg_i_for_call(Arg, 0, Mapping),
    \+ kb_keyword_arg_for_call(_, Arg, Mapping).

% -----------------------------------------------------------------------------
% endpoints_user_input_spring( Param )
%
% A param of a spring handler that spring binds from the request :
%
%   @GetMapping( "/items/{id}" )
%   public Item item( @PathVariable String id, @RequestParam String q ) { ... }
%
% Both `id` and `q` are user input. Like every annotation, the param's
% annotation is lowered as a call at its own location, so its fqn comes
% from `kb_call_resolved/2`.

endpoints_user_input_spring(Param) :-
    kb_param_has_annotation(Param, Annotation),
    kb_call_resolved(Annotation, Fqn),
    endpoints_user_input_annotation_spring(Fqn),
    kb_param_i_of_callable(Param, _, Handler),
    once(endpoints_http_spring(Handler, _, _, _)).

endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.RequestParam').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.PathVariable').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.RequestBody').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.RequestHeader').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.CookieValue').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.RequestPart').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.MatrixVariable').
endpoints_user_input_annotation_spring('org.springframework.web.bind.annotation.ModelAttribute').

% -----------------------------------------------------------------------------
% endpoints_http_auth_spring( Handler, Name, Annotations )
%
% `Handler` is guarded by the security annotations `Annotations`, a
% list of sec( Fqn, Annotation, ConstStrArgs ) :
%
%   @PreAuthorize( "hasAuthority('ADMIN')" )   --> [ 'hasAuthority(\'ADMIN\')' ]
%   @Secured( { "ROLE_A", "ROLE_B" } )         --> [ 'ROLE_A', 'ROLE_B' ]
%
% `Name` is the short name of the first one ( 'PreAuthorize' ).
%
% Spring checks each group ( `endpoints_security_annotation_spring/2` )
% on its own : inside a group the method annotation overrides the class
% one, and every group in effect applies. Annotations that let anyone in
% ( `permitAll()`, `@PermitAll`, ... ) guard nothing, so a handler with
% only those stays unauthenticated.

endpoints_http_auth_spring(Handler, Name, Annotations) :-
    findall(Annotation, endpoints_security_in_effect_spring(Handler, Annotation), Annotations),
    member(sec(Fqn, _, ConstStrArgs), Annotations),
    \+ endpoints_open_security_spring(Fqn, ConstStrArgs),
    !,
    Annotations = [ sec(First, _, _) | _ ],
    atomic_list_concat(Parts, '.', First),
    last(Parts, Name).

endpoints_security_in_effect_spring(Handler, sec(Fqn, Annotation, ConstStrArgs)) :-
    member(Group, [ preauthorize, secured, jsr250 ]),
    once(( endpoints_effective_annotation_spring(Handler, Annotation, Fqn),
           endpoints_security_annotation_spring(Fqn, Group) )),
    endpoints_const_str_args_spring(Annotation, ConstStrArgs).

endpoints_security_annotation_spring('org.springframework.security.access.prepost.PreAuthorize', preauthorize).
endpoints_security_annotation_spring('org.springframework.security.access.annotation.Secured', secured).
endpoints_security_annotation_spring('jakarta.annotation.security.RolesAllowed', jsr250).
endpoints_security_annotation_spring('jakarta.annotation.security.PermitAll', jsr250).
endpoints_security_annotation_spring('jakarta.annotation.security.DenyAll', jsr250).
endpoints_security_annotation_spring('javax.annotation.security.RolesAllowed', jsr250).
endpoints_security_annotation_spring('javax.annotation.security.PermitAll', jsr250).
endpoints_security_annotation_spring('javax.annotation.security.DenyAll', jsr250).

% -----------------------------------------------------------------------------
% endpoints_const_str_args_spring( Annotation, ConstStrArgs )
%
% The constant string args of `Annotation`, in order, with array args
% ( `{ "a", "b" }`, lowered as a `new_array` call ) flattened. Args
% that are not constant strings are skipped.

endpoints_const_str_args_spring(Annotation, ConstStrArgs) :-
    findall(Index-Strs, ( kb_arg_i_for_call(Arg, Index, Annotation), endpoints_const_str_arg_spring(Arg, Strs) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Nested),
    append(Nested, ConstStrArgs).

endpoints_const_str_arg_spring(Arg, [ Str ]) :-
    kb_const_string(Arg, Str),
    !.
endpoints_const_str_arg_spring(Arg, Strs) :-
    kb_call_resolved(Arg, '<dhscanner-instrumentation>[new_array]'),
    findall(Index-Str, ( kb_arg_i_for_call(Elem, Index, Arg), kb_const_string(Elem, Str) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Strs).

endpoints_open_security_spring('jakarta.annotation.security.PermitAll', _).
endpoints_open_security_spring('javax.annotation.security.PermitAll', _).
endpoints_open_security_spring(_, [ Expression ]) :-
    split_string(Expression, "", " \t", [ Trimmed ]),
    memberchk(Trimmed, [ "permitAll()", "permitAll", "isAnonymous()", "IS_AUTHENTICATED_ANONYMOUSLY" ]).
