:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_sqli_python_django( Call )
%
% Where SQL text enters the database layer in Django :
%
%   raw cursor : `connection.cursor().execute( sql, params )` resolves to
%     'django.db.connection.cursor.execute' ( 'django.db.connections.cursor.execute'
%     for `connections[ alias ]` ), and `executemany`.
%   ORM escape hatches : `Model.objects.raw( sql )`, `QuerySet.extra( where = ... )`
%     and `RawSQL( sql, params )`. The receiver of `raw` / `extra` is the
%     model's manager or a queryset, so these match on the method suffix.
%
% The rest of the ORM builds parameterized queries, so it is not listed.
%
% First sensor on Weblate `0195e965e6` : `django.db.connections.cursor.execute`
% 5, `django.db.connection.cursor.execute` 3 ( runner #129 ).
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_sqli_python_django(Call) :-
    kb_call_resolved(Call, Fqn),
    django_sql_text_fqn(Fqn).

django_sql_text_fqn('django.db.connection.cursor.execute').
django_sql_text_fqn('django.db.connection.cursor.executemany').
django_sql_text_fqn('django.db.connections.cursor.execute').
django_sql_text_fqn('django.db.connections.cursor.executemany').
django_sql_text_fqn('django.db.models.expressions.RawSQL').
django_sql_text_fqn(Fqn) :- atom_concat(_, '.objects.raw', Fqn).
django_sql_text_fqn(Fqn) :- atom_concat(_, '.extra', Fqn).
