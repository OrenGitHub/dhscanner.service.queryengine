:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Django HTTP endpoint recognizers ( runner #126 ).
%
% Django routing lives in `urls.py` : `path( Url, View, ... )` and
% `re_path( Url, View, ... )` from `django.urls`. The View is either
%
%   - a class-based view : the call `X.as_view()`, its fqn ends with
%     `.as_view` ( eg 'weblate.api.views.Metrics.as_view' ), or
%   - a function view : a dotted reference ( `weblate.wladmin.views.alerts`
%     after `import weblate.wladmin.views` ), a `kb_field_read_resolved/2`,
%     or a function of the same file, whose arg location is its def.
%
% Absolute python imports reach the KB by name, 1st party or not. A
% dotted module `a.b.c` is 1st party when the KB has a definition in
% `a/b/c.py` or `a/b/c/__init__.py` ( `python_module_file/2` ), which is
% how `python_class_by_fqn/2` and `python_func_by_fqn/2` resolve a name.
%
% Not covered yet : `include(...)` url prefixes ( the url is the local
% route only ), DRF routers, and class-based views that inherit every
% verb method from django's generic views.
%
% Not every KB carries these facts ( non-python KBs ), so declare them
% here to keep calls to them failing quietly rather than raising.

:- dynamic kb_call_resolved/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_const_string/2.
:- dynamic kb_field_read_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_class_def/3.
:- dynamic kb_method_of_class/2.
:- dynamic kb_method_has_name/2.
:- dynamic kb_class_has_1st_party_super/3.
:- dynamic kb_param_i_of_callable/3.
:- dynamic kb_param_has_name/2.

% -----------------------------------------------------------------------------
% endpoints_http_django( Handler, Verb, Request, Url )
%
% Class-based view : the `get` / `post` / `put` / `patch` / `delete`
% method of the view class or of one of its 1st party supers.
% Function view : the function itself, with verb `unknown` ( the verb
% is checked inside the function, if at all ).
%
% `Request` is the handler's `request` param ( param 1 of a method,
% after `self`, param 0 of a function ), else the handler itself.

endpoints_http_django(Handler, Verb, Request, Url) :-
    endpoints_route_django(Url, View),
    endpoints_view_class_django(View, Class),
    endpoints_verb_method_django(Name, Verb),
    python_method_resolved(Class, Name, Handler),
    endpoints_request_django(Handler, 1, Request).

endpoints_http_django(Handler, unknown, Request, Url) :-
    endpoints_route_django(Url, View),
    endpoints_view_func_django(View, Handler),
    endpoints_request_django(Handler, 0, Request).

% -----------------------------------------------------------------------------
% endpoints_route_django( Url, View )
%
% `django.urls.path( Url, View, ... )` / `re_path`, with a const string url.

endpoints_route_django(Url, View) :-
    kb_call_resolved(Call, Fqn),
    endpoints_route_fqn_django(Fqn),
    kb_arg_i_for_call(UrlArg, 0, Call),
    kb_const_string(UrlArg, Url),
    kb_arg_i_for_call(View, 1, Call).

endpoints_route_fqn_django('django.urls.path').
endpoints_route_fqn_django('django.urls.re_path').

endpoints_view_class_django(View, Class) :-
    kb_call_resolved(View, Fqn),
    atom_concat(ClassFqn, '.as_view', Fqn),
    python_class_by_fqn(ClassFqn, Class).

endpoints_view_func_django(View, Func) :-
    kb_field_read_resolved(View, Fqn),
    python_func_by_fqn(Fqn, Func).
endpoints_view_func_django(View, View) :-
    kb_func_def(View, _, _, _).

endpoints_verb_method_django(get, get).
endpoints_verb_method_django(post, post).
endpoints_verb_method_django(put, put).
endpoints_verb_method_django(patch, patch).
endpoints_verb_method_django(delete, delete).

endpoints_request_django(Handler, Index, Request) :-
    kb_param_i_of_callable(Request, Index, Handler),
    kb_param_has_name(Request, request),
    !.
endpoints_request_django(Handler, _, Handler).

% -----------------------------------------------------------------------------
% python_class_by_fqn( Fqn, Class )
% python_func_by_fqn( Fqn, Func )
%
% 'weblate.trans.views.about.AboutView' -> the class `AboutView` defined
% in `weblate/trans/views/about.py` ( or `.../about/__init__.py` ).

python_class_by_fqn(Fqn, Class) :-
    python_module_and_name(Fqn, File, Name),
    kb_class_def(Class, Name, File),
    !.

python_func_by_fqn(Fqn, Func) :-
    python_module_and_name(Fqn, File, Name),
    kb_func_def(Func, Name, File, _),
    !.

python_module_and_name(Fqn, File, Name) :-
    atomic_list_concat(Parts, '.', Fqn),
    append(ModuleParts, [Name], Parts),
    ModuleParts \= [],
    python_module_file(ModuleParts, File).

python_module_file(ModuleParts, File) :-
    atomic_list_concat(ModuleParts, '/', Path),
    (   atom_concat(Path, '.py', File)
    ;   atom_concat(Path, '/__init__.py', File)
    ).

% -----------------------------------------------------------------------------
% python_method_resolved( Class, Name, Method )
%
% The method `Name` that a `Class` instance calls : its own, else the
% nearest one up its 1st party supers ( an override hides the super's ).

python_method_resolved(Class, Name, Method) :-
    once(( python_class_or_1st_party_super(Class, Hosting),
           kb_method_of_class(Method, Hosting),
           kb_method_has_name(Method, Name) )).

% -----------------------------------------------------------------------------
% python_class_or_1st_party_super( Class, Hosting )
%
% `Class` itself, then its 1st party supers up to 8 levels up ( cycle
% safe ), nearest first : the order `python_method_resolved/3` relies on.

python_class_or_1st_party_super(Class, Hosting) :-
    python_class_or_1st_party_super(Class, Hosting, 8).

python_class_or_1st_party_super(Class, Class, _).
python_class_or_1st_party_super(Class, Hosting, Depth) :-
    Depth > 0,
    Depth1 is Depth - 1,
    kb_class_has_1st_party_super(Class, SuperName, File),
    kb_class_def(Super, SuperName, File),
    python_class_or_1st_party_super(Super, Hosting, Depth1).
