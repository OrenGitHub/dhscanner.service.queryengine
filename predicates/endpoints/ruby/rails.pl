:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Rails ( action pack ) HTTP endpoint recognizers ( runner #138 ).
%
% A Rails endpoint is an action : a method of a controller class. Rails
% finds controllers by convention, not by imports ( zeitwerk autoload ) :
% `Admin::UsersController` lives in `app/controllers/admin/users_controller.rb`,
% and a plugin's in `plugins/<name>/app/controllers/...`. The super chain
% ( `< ApplicationController < ActionController::Base` ) names constants
% that are never imported, so the KB has no resolved supers for them :
% the recognizer goes by the same convention Rails does. A controller is
% a class whose name ends with `Controller`, defined in a file under a
% `controllers/` directory.
%
% Verb : the resourceful actions ( `resources :posts` ) have a fixed verb,
% every other action is `unknown`. Url : `{?}`, routes ( `config/routes.rb` )
% are not read yet.
%
% Private / protected methods are not actions : the parser gives every
% `def` after a bare `private` / `protected` the annotation
% `<dhscanner-instrumentation>[private]` ( `[protected]` ). Ruby has no
% other method annotations, so any annotation means not routable.
%
% Not covered yet : `private def x` ( inline form ), actions inherited from
% a 1st party super controller, and routes.
%
% Not every KB carries these facts, so declare them here to keep calls to
% them failing quietly rather than raising.

:- dynamic kb_class_def/3.
:- dynamic kb_method_of_class/2.
:- dynamic kb_method_has_name/2.
:- dynamic kb_callable_has_annotation/2.

% -----------------------------------------------------------------------------
% endpoints_http_rails( Handler, Verb, Request, Url )
%
% Rails actions have no request param ( `params` / `request` are methods
% of the controller ), so the request slot carries the handler itself.

endpoints_http_rails(Handler, Verb, Handler, '{?}') :-
    endpoints_controller_rails(Class),
    kb_method_of_class(Handler, Class),
    kb_method_has_name(Handler, Name),
    \+ endpoints_non_action_rails(Name),
    \+ kb_callable_has_annotation(Handler, _),
    endpoints_action_verb_rails(Name, Verb).

% -----------------------------------------------------------------------------
% endpoints_controller_rails( Class )

endpoints_controller_rails(Class) :-
    kb_class_def(Class, Name, File),
    atom_concat(_, 'Controller', Name),
    endpoints_controller_file_rails(File).

endpoints_controller_file_rails(File) :- sub_atom(File, 0, _, _, 'controllers/'), !.
endpoints_controller_file_rails(File) :- sub_atom(File, _, _, _, '/controllers/'), !.

% -----------------------------------------------------------------------------
% endpoints_action_verb_rails( Action, Verb )
%
% The verbs of `resources :x` : `update` answers both PATCH and PUT,
% PATCH is the one Rails generates links / forms for.

endpoints_action_verb_rails(index, get) :- !.
endpoints_action_verb_rails(show, get) :- !.
endpoints_action_verb_rails(new, get) :- !.
endpoints_action_verb_rails(edit, get) :- !.
endpoints_action_verb_rails(create, post) :- !.
endpoints_action_verb_rails(update, patch) :- !.
endpoints_action_verb_rails(destroy, delete) :- !.
endpoints_action_verb_rails(_, unknown).

% methods Rails never routes to : ruby hooks / operators.
endpoints_non_action_rails(initialize).
endpoints_non_action_rails(Name) :- sub_atom(Name, 0, 1, _, '_').
