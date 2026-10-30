:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Python file sinks : builtin `open`, `pathlib`, `os`, `shutil`, archives
% and django's `FileResponse`.
%
% One fqn per clause, split by what the call does to the file :
%
%   read     -> `sinks_arbitrary_file_read_python( Call )`
%   write    -> `sinks_arbitrary_file_write_python( Arg )`  ( the path arg,
%               same convention as `sinks/files/java/native.pl` )
%   delete   -> `sinks_arbitrary_file_deletion_python( Call )`
%
% `open( path, mode )` reads or writes depending on its mode, which the kb
% doesn't keep, so it is listed as a read.
%
% `pathlib.Path` methods take the path as their receiver : `Path( p ).read_text()`
% resolves to 'pathlib.Path.read_text', but a path kept in a variable resolves
% to `Unknown.read_text`. `read_text`, `read_bytes`, `write_text`, `write_bytes`
% are specific enough to match on the method suffix ( like `.createQuery` in
% `sinks/db/java/jpa.pl` ). Their write arg is the content ( the only arg ).
%
% First sensor on Weblate `0195e965e6` : `open` 25, `pathlib.Path.read_text`
% 12, `Unknown.write_text` 38, `os.unlink` 9, `django.http.FileResponse` 5
% ( runner #129 ).
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_arbitrary_file_read_python(Call) :-
    kb_call_resolved(Call, Fqn),
    python_file_read_fqn(Fqn).

sinks_arbitrary_file_write_python(Arg) :-
    kb_call_resolved(Call, Fqn),
    python_file_write_fqn(Fqn, I),
    kb_arg_i_for_call(Arg, I, Call).

sinks_arbitrary_file_deletion_python(Call) :-
    kb_call_resolved(Call, Fqn),
    python_file_delete_fqn(Fqn).

python_file_read_fqn('open').
python_file_read_fqn('io.open').
python_file_read_fqn('codecs.open').
python_file_read_fqn('pathlib.Path.open').
python_file_read_fqn('tarfile.open').
python_file_read_fqn('zipfile.ZipFile').
python_file_read_fqn('django.http.FileResponse').
python_file_read_fqn(Fqn) :- atom_concat(_, '.read_text', Fqn).
python_file_read_fqn(Fqn) :- atom_concat(_, '.read_bytes', Fqn).

% python_file_write_fqn( Fqn, index of the path arg )
python_file_write_fqn('shutil.copy', 1).
python_file_write_fqn('shutil.copy2', 1).
python_file_write_fqn('shutil.copyfile', 1).
python_file_write_fqn('shutil.copytree', 1).
python_file_write_fqn('shutil.move', 1).
python_file_write_fqn('os.rename', 1).
python_file_write_fqn('os.replace', 1).
python_file_write_fqn(Fqn, 0) :- atom_concat(_, '.write_text', Fqn).
python_file_write_fqn(Fqn, 0) :- atom_concat(_, '.write_bytes', Fqn).

python_file_delete_fqn('os.remove').
python_file_delete_fqn('os.unlink').
python_file_delete_fqn('os.rmdir').
python_file_delete_fqn('os.removedirs').
python_file_delete_fqn('shutil.rmtree').
python_file_delete_fqn('pathlib.Path.unlink').
python_file_delete_fqn('pathlib.Path.rmdir').
