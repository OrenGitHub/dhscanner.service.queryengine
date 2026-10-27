:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_sqli_java_jpa( Call )
%
% Where SQL / JPQL / HQL text enters the database layer in Java :
%
%   JPA / hibernate : `createQuery`, `createNativeQuery`, `createSQLQuery`
%     The receiver ( an `EntityManager` or hibernate `Session` ) is often
%     unresolved in the kb ( `Unknown.createQuery`,
%     `Unknown.getHibernateSession.createQuery` ), so these match on the
%     method suffix. The criteria api `CriteriaBuilder.createQuery` takes a
%     result class, not query text, so it is not a sink.
%
%   JDBC : `Connection.prepareStatement` / `prepareCall` and the
%     `Statement.execute*` / `addBatch` family that take the sql string.
%
% The follow-up `executeUpdate()` / `getResultList()` on a JPA query takes
% no text, so it is not listed : one sink per statement, at the call that
% receives the text.
%
% First end-to-end sensor on DSpace 10.1 : `GroupDAOImpl.delete` runs
% `createNativeQuery( "DELETE FROM group2group WHERE ..." )` at `:204`,
% a const string with a bound parameter ( runner #119 ).
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_sqli_java_jpa(Call) :-
    kb_call_resolved(Call, Fqn),
    java_sql_text_fqn(Fqn).

java_sql_text_fqn(Fqn) :-
    java_sql_text_method_suffix(Suffix),
    atom_concat(_, Suffix, Fqn),
    \+ sub_atom(Fqn, _, _, _, '.criteria.CriteriaBuilder.').
java_sql_text_fqn(Fqn) :-
    java_jdbc_fqn(Fqn).

java_sql_text_method_suffix('.createQuery').
java_sql_text_method_suffix('.createNativeQuery').
java_sql_text_method_suffix('.createSQLQuery').

java_jdbc_fqn('java.sql.Connection.prepareStatement').
java_jdbc_fqn('java.sql.Connection.prepareCall').
java_jdbc_fqn('java.sql.Statement.execute').
java_jdbc_fqn('java.sql.Statement.executeQuery').
java_jdbc_fqn('java.sql.Statement.executeUpdate').
java_jdbc_fqn('java.sql.Statement.executeLargeUpdate').
java_jdbc_fqn('java.sql.Statement.addBatch').
