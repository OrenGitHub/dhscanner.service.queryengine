:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Java file sinks : java.io, java.nio.file.Files and commons-io FileUtils.
%
% One fqn per clause, split by what the call does to the file :
%
%   read     -> `sinks_arbitrary_file_read_java( Call )`
%   write    -> `sinks_arbitrary_file_write_java( Arg )`  ( the path arg,
%               same convention as `sinks/files/nodejs/native.pl` )
%   delete   -> `sinks_arbitrary_file_deletion_java( Call )`
%
% Constructors resolve to the class fqn itself ( `new FileInputStream( f )`
% is a call to 'java.io.FileInputStream' ). Plain `new File( ... )` is not a
% sink : it only builds a path, the stream / Files call on it is the sink.
%
% First end-to-end sensor on DSpace 10.1 : unauth `GET /sitemaps/{name}`
% ( `SitemapRestController.java:70` ) reads `new FileInputStream( ... )` at
% `:119`, guarded by an `equalsIgnoreCase` allow-list over
% `sitemapOutputDir.listFiles()` ( runner #119 ).
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_arbitrary_file_read_java(Call) :-
    kb_call_resolved(Call, Fqn),
    java_file_read_fqn(Fqn).

sinks_arbitrary_file_write_java(Arg) :-
    kb_arg_i_for_call(Arg, 0, Call),
    kb_call_resolved(Call, Fqn),
    java_file_write_fqn(Fqn).

sinks_arbitrary_file_deletion_java(Call) :-
    kb_call_resolved(Call, Fqn),
    java_file_delete_fqn(Fqn).

java_file_read_fqn('java.io.FileInputStream').
java_file_read_fqn('java.io.FileReader').
java_file_read_fqn('java.io.RandomAccessFile').
java_file_read_fqn('java.nio.file.Files.readAllBytes').
java_file_read_fqn('java.nio.file.Files.readAllLines').
java_file_read_fqn('java.nio.file.Files.readString').
java_file_read_fqn('java.nio.file.Files.lines').
java_file_read_fqn('java.nio.file.Files.newInputStream').
java_file_read_fqn('java.nio.file.Files.newBufferedReader').
java_file_read_fqn('org.apache.commons.io.FileUtils.readFileToString').
java_file_read_fqn('org.apache.commons.io.FileUtils.readFileToByteArray').
java_file_read_fqn('org.apache.commons.io.FileUtils.readLines').
java_file_read_fqn('org.apache.commons.io.FileUtils.openInputStream').

java_file_write_fqn('java.io.FileOutputStream').
java_file_write_fqn('java.io.FileWriter').
java_file_write_fqn('java.nio.file.Files.write').
java_file_write_fqn('java.nio.file.Files.writeString').
java_file_write_fqn('java.nio.file.Files.newOutputStream').
java_file_write_fqn('java.nio.file.Files.newBufferedWriter').
java_file_write_fqn('java.nio.file.Files.copy').
java_file_write_fqn('java.nio.file.Files.move').
java_file_write_fqn('org.apache.commons.io.FileUtils.write').
java_file_write_fqn('org.apache.commons.io.FileUtils.writeStringToFile').
java_file_write_fqn('org.apache.commons.io.FileUtils.writeByteArrayToFile').
java_file_write_fqn('org.apache.commons.io.FileUtils.copyInputStreamToFile').
java_file_write_fqn('org.apache.commons.io.FileUtils.copyFile').
java_file_write_fqn('org.apache.commons.io.FileUtils.moveFile').

java_file_delete_fqn('java.io.File.delete').
java_file_delete_fqn('java.nio.file.Files.delete').
java_file_delete_fqn('java.nio.file.Files.deleteIfExists').
java_file_delete_fqn('org.apache.commons.io.FileUtils.deleteDirectory').
java_file_delete_fqn('org.apache.commons.io.FileUtils.forceDelete').
java_file_delete_fqn('org.apache.commons.io.FileUtils.deleteQuietly').
