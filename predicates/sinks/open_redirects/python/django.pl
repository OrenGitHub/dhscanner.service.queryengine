:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_open_redirect_python_django( Call )
%
% Django answers with a 302 / 301 through `django.shortcuts.redirect( to )`
% and the `HttpResponseRedirect( url )` / `HttpResponsePermanentRedirect( url )`
% responses. `redirect` takes a url, a model ( its `get_absolute_url()` )
% or a url pattern name ( reversed ), so most calls are safe : telling them
% apart is the agent's job, on top of this sink.
%
% First sensor on Weblate `0195e965e6` : `django.shortcuts.redirect` 178,
% `HttpResponseRedirect` 30, `HttpResponsePermanentRedirect` 2, eg
% `auto_translation` ( `trans/views/edit.py:1517` ) redirects to the model
% it was called on ( runner #129 ).
%
% Same convention as the other open-redirect sinks : no taint check
% here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_open_redirect_python_django(Call) :-
    kb_call_resolved(Call, Fqn),
    django_redirect_fqn(Fqn).

django_redirect_fqn('django.shortcuts.redirect').
django_redirect_fqn('django.http.HttpResponseRedirect').
django_redirect_fqn('django.http.HttpResponsePermanentRedirect').
django_redirect_fqn('django.http.response.HttpResponseRedirect').
django_redirect_fqn('django.http.response.HttpResponsePermanentRedirect').
