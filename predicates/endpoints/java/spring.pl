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
% `endpoints_mapping_verb_spring/2` ). `Url` is the hosting class
% prefix followed by the method path.

endpoints_http_spring(Handler, Verb, Url, Mapping) :-
    kb_callable_has_annotation(Handler, Mapping),
    kb_call_resolved(Mapping, Fqn),
    endpoints_mapping_verb_spring(Fqn, Verb),
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
% endpoints_mapping_verb_spring( Fqn, Verb )
%
% The composed `@XxxMapping` annotations fix the verb by name.
%
% `@RequestMapping` carries it in `method = RequestMethod.X`, but the
% KB does not resolve that yet : enum constants have no resolved fqn.
% Until it does, such handlers are reported with `unresolved` rather
% than guessed.

endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.GetMapping', get).
endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.PostMapping', post).
endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.PutMapping', put).
endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.DeleteMapping', delete).
endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.PatchMapping', patch).
endpoints_mapping_verb_spring('org.springframework.web.bind.annotation.RequestMapping', unresolved).

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
