(**************************************************************************)
(*   Ocaml-fileutils                                                      *)
(*                                                                        *)
(*   Copyright (C) 2003, 2004 Sylvain Le Gall <sylvain@le-gall.net>       *)
(*                                                                        *)
(*   This program is free software; you can redistribute it and/or        *)
(*   modify it under the terms of the GNU Library General Public          *)
(*   License as published by the Free Software Foundation; either         *)
(*   version 2 of the License, or any later version ; with the OCaml      *)
(*   static compilation exception.                                        *)
(*                                                                        *)
(*   This program is distributed in the hope that it will be useful,      *)
(*   but WITHOUT ANY WARRANTY; without even the implied warranty of       *)
(*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                 *)
(*   See the LICENCE file for more details.                               *)
(*                                                                        *)
(*   You should have received a copy of the GNU General Public License    *)
(*   along with this program; if not, write to the Free Software          *)
(*   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA             *)
(*   02111-1307  USA                                                      *)
(*                                                                        *)
(*   Contact: sylvain@le-gall.net                                         *)
(*                                                                        *)
(**************************************************************************)

(** A module to provide the core system utilities to 
manipulate file and directory. All function nearly match
common unix utilities ( but try to be more portable )*)

(** {1 Exceptions}*)

exception File_doesnt_exist
exception RmDirNotEmpty
exception MkdirMissingComponentPath
exception MkdirDirnameAlreadyUsed
exception CpCannotCopyDirToDir
exception CpCannotCopyDirToFile
exception CpCannotCopy
exception CpNoSourceFile
exception MvNoSourceFile

open FilePath.DefaultPath

(** {1 File utils specification} *)

(** Abstraction of regexp operation *)
module type OPERATION_REGEXP = 
sig
	type t
	val compile : string -> t
	val test    : t -> string -> bool
end
;;

(** Operation available. Filename are considered to be valid filename for the current
    running OS *)
module type FILE_UTILS =
sig
	(** Module to manipulate real file *)

	(** {2 Types}*)

	(** The base type of the module *)
	type filename = string

	(** {2 Testing file} *)

	(** For certain command, you should need to ask the user wether
	    or not he does want to do some action. Provide the function 
	    to Ask or Force the action *)
	type interactive =
		  Force
		(** Do it anyway *)
		| Ask of (filename -> bool)
		(** Promp the user *)

	(** Pattern you can use to test file *)
	type test_file =
		Is_dev_block
		(** FILE exists and is block special *)
		| Is_dev_char
		(** FILE exists and is character special *)
		| Is_dir
		(** FILE exists and is a directory *)
		| Exists
		(** FILE exists *)
		| Is_file
		(** FILE exists and is a regular file *)
		| Is_set_group_ID
		(** FILE exists and is set-group-ID *)
		| Has_sticky_bit
		(** FILE exists and has its sticky bit set *)
		| Is_link
		(** FILE exists and is a symbolic link *)
		| Is_pipe
		(** FILE exists and is a named pipe *)
		| Is_readable
		(** FILE exists and is readable *)
		| Is_writeable
		(** FILE exists and is writeable *)
		| Size_not_null
		(** FILE exists and has a size greater than zero *)
		| Is_socket
		(** FILE exists and is a socket *)
		| Has_set_user_ID
		(** FILE exists and its set-user-ID bit is set *)
		| Is_exec
		(** FILE exists and is executable *)
		| Is_owned_by_user_ID
		(** FILE exists and is owned by the effective user ID *)
		| Is_owned_by_group_ID
		(** FILE exists and is owned by the effective group ID *)
		| Is_newer_than of filename * filename
		(** FILE1 is newer (modification date) than FILE2 *)
		| Is_older_than of filename * filename
		(** FILE1 is older than FILE2 *)
		| Has_same_device_and_inode of filename * filename
		(** FILE1 and FILE2 have the same device and inode numbers *)
		| And of test_file * test_file
		(** Result of TEST1 and TEST2 *)
		| Or of test_file * test_file
		(** Result of TEST1 or TEST2 *)
		| Not of test_file
		(** Result of not TEST *)
		| Match of string
		(** Match regexp *)
		| True
		(** Always true *)
		| False
		(** Always false *)
		| Has_extension of string
		(** Check extension *)
		| Is_parent_dir 
		(** Is it the parent dir *)
		| Is_current_dir
		(** Is it the current dir *)

	(** {2 Common operation on file }*)

	(** List the content of a directory *)
	val ls : filename -> filename list

	(** Apply a filtering pattern to a filename *)
	val filter : test_file -> filename list -> filename list

	(** Test the existence of the file... *)
	val test : test_file -> filename -> bool

	(** Try to find the executable in the PATH. Use environement variable
	PATH if none is provided *)
	val which : ?path:filename list -> filename -> filename

	(** Create the directory which name is provided. Turn parent to true
	if you also want to create every topdir of the path. Use mode to 
	provide some specific right ( default 755 ). *)
	val mkdir : ?parent:bool -> ?mode:int -> filename -> unit

	(** Modify the time stamp of the given filename. Turn create to false
	if you don't want to create the file *)
	val touch : ?create:bool -> filename -> unit

	(** Descend the directory tree starting from the given filename and using
	the test provided to find what is looking for. You cannot match current_dir
	and parent_dir.*)
	val find : test_file -> filename -> filename list

	(** Remove the filename provided. Turn recurse to true in order to 
	completely delete a directory *)
	val rm : ?force:interactive -> ?recurse:bool -> filename -> unit

	(** Copy the hierarchy of files/directory to another destination *)
	val cp : ?force:interactive -> ?recurse:bool -> filename -> filename -> unit

	(** Move files/directory to another destination *)
	val mv : ?force:interactive -> filename -> filename -> unit
end
;;

(** Meta structure use to define regexp generic file operation *)
module type META_FILE_UTILS = 
functor ( OperationRegexp : OPERATION_REGEXP ) -> FILE_UTILS
;;

(** Implementation of META_FILE_UTILS *)
module GenericUtil : META_FILE_UTILS =
functor ( OperationRegexp : OPERATION_REGEXP ) ->
struct
	type filename = string

	type interactive =
		  Force
		| Ask of (string -> bool)

	type fs_type = 
		Dir  
		| File 
		| Dev_char
		| Dev_block
		| Link
		| Fifo
		| Socket

	type test_file =
		Is_dev_block
		| Is_dev_char
		| Is_dir
		| Exists
		| Is_file
		| Is_set_group_ID
		| Has_sticky_bit
		| Is_link
		| Is_pipe
		| Is_readable
		| Is_writeable
		| Size_not_null
		| Is_socket
		| Has_set_user_ID
		| Is_exec
		| Is_owned_by_user_ID
		| Is_owned_by_group_ID
		| Is_newer_than of string * string
		| Is_older_than of string * string
		| Has_same_device_and_inode of string * string
		| And of test_file * test_file
		| Or of test_file * test_file
		| Not of test_file
		| Match of string
		| True
		| False
		| Has_extension of string
		| Is_parent_dir
		| Is_current_dir

	let stat_type filename =
		try
			let stats = Unix.stat filename
			in
			match stats.Unix.st_kind with
			  Unix.S_REG -> File 
			| Unix.S_DIR -> Dir 
			| Unix.S_CHR -> Dev_char 
			| Unix.S_BLK -> Dev_block
			| Unix.S_LNK -> Link
			| Unix.S_FIFO -> Fifo 
			| Unix.S_SOCK -> Socket
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist 

	let stat_type_match tp filename = stat_type filename = tp

	let stat_right filename =
		try
			let stats = Unix.stat filename
			in
			stats.Unix.st_perm 
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let stat_right_match right filename = 
		(stat_right filename land right) <> 0

	let right_sticky       = 0o1000
	let right_sticky_group = 0o2000
	let right_sticky_user  = 0o4000
	let right_exec         = 0o0111
	let right_write        = 0o0222
	let right_read         = 0o0444

	let stat_size filename =
		try
			let stats = Unix.stat filename
			in
			stats.Unix.st_size
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let stat_ugid filename =
		try
			let stats = Unix.stat filename
			in
			(stats.Unix.st_uid,stats.Unix.st_gid)
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let stat_mtime filename =
		try
			let stats = Unix.stat filename
			in
			stats.Unix.st_mtime
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let stat_dev filename =
		try
			let stats = Unix.stat filename
			in
			(stats.Unix.st_dev,stats.Unix.st_rdev)
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let stat_inode filename =
		try
			let stats = Unix.stat filename
			in
			stats.Unix.st_ino
		with Unix.Unix_error(_) ->
			raise File_doesnt_exist

	let rec compile_filter flt =
		let res_filter =
			match flt with
			  Is_dev_block    -> stat_type_match Dev_block
			| Is_dev_char     -> stat_type_match Dev_char
			| Is_dir          -> stat_type_match Dir
			| Is_file         -> stat_type_match File
			| Is_set_group_ID -> stat_right_match right_sticky_group
			| Has_sticky_bit  -> stat_right_match right_sticky
			| Is_link         -> stat_type_match Link
			| Is_pipe         -> stat_type_match Fifo
			| Is_readable     -> stat_right_match right_read
			| Is_writeable    -> stat_right_match right_write
			| Size_not_null   -> fun x -> (stat_size x) > 0
			| Is_socket       -> stat_type_match Socket
			| Has_set_user_ID -> stat_right_match right_sticky_user
			| Is_exec         -> stat_right_match right_exec
			| True            -> fun x -> true
			| False           -> fun x -> false
			| Is_owned_by_user_ID  -> fun x -> Unix.geteuid () = fst (stat_ugid x)
			| Is_owned_by_group_ID -> fun x -> Unix.getegid () = snd (stat_ugid x)
			| Is_newer_than(f1,f2) -> fun x -> 
				(stat_mtime f1) < (stat_mtime f2)
			| Is_older_than(f1,f2) -> fun x -> (stat_mtime f1) > (stat_mtime f2)
			| Has_same_device_and_inode(f1,f2) -> 
				fun x -> (stat_dev f1,stat_inode f1) = (stat_dev f2, stat_inode f2)
			| Exists	  -> fun x -> let _ = stat_right x in  true
			| And(flt1,flt2) ->
				begin
				fun x -> 
					let cflt1 = (compile_filter flt1)
					in
					let cflt2 = (compile_filter flt2)
					in
					(cflt1 x) && (cflt2 x)
				end
			| Or(flt1,flt2) ->
				begin
				fun x -> 
					let cflt1 = (compile_filter flt1)
					in
					let cflt2 = (compile_filter flt2)
					in
					(cflt1 x) || (cflt2 x)
				end
			| Not(flt1) ->
				begin
				fun x -> 
					let cflt1 = (compile_filter flt1)
					in
					not (cflt1 x)
				end	
			| Match(r) ->
				begin
				let reg = OperationRegexp.compile r
				in
				fun x -> OperationRegexp.test reg x
				end
			| Has_extension(ext) ->
				fun x -> check_extension x (extension_of_string ext)
			| Is_current_dir ->
				fun x -> (is_current (basename x))
			| Is_parent_dir ->
				fun x -> (is_parent  (basename x))
		in
		fun x -> ( try res_filter x with File_doesnt_exist -> false )

	let ls dirname =
		let array_dir = Sys.readdir dirname
		in
		let list_dir  = Array.to_list array_dir
		in
		List.map (fun x -> concat dirname x)  list_dir


	let filter flt lst =
		let cflt = compile_filter flt
		in
		List.filter cflt lst

	let test tst fln =
		let ctst = compile_filter tst
		in
		ctst fln 

	let which ?(path) fln =
		let real_path =
			match path with
			  None ->
				path_of_string (Sys.getenv "PATH")
			| Some x ->
				x
		in
		let ctst x = 
			test (And(Is_exec,Not(Is_dir))) 
				(concat x fln)
		in
		let which_path =
			List.find ctst real_path
		in
		concat which_path fln

	let mkdir ?(parent=false) ?mode fln =
		let real_mode = 
			match mode with
			  Some x -> x
			| None -> 0o0755
		in
		let mkdir_simple fln =
			if test Exists fln then
				if test Is_dir fln then
					()
				else
					raise MkdirDirnameAlreadyUsed 
			else
				try 
					Unix.mkdir fln real_mode 
				with Unix.Unix_error(Unix.ENOENT,_,_) | Unix.Unix_error(Unix.ENOTDIR,_,_) ->
					raise MkdirMissingComponentPath
		in
		if parent then
			let rec create_parent parent =
				let _ =
					if test Exists parent then
						()
					else
						create_parent (dirname parent)
				in
				mkdir_simple parent
			in
			create_parent fln
		else
			mkdir_simple fln

	let touch ?(create=true) fln =
		if (test (And(Exists,Is_file)) fln) || create then
			close_out (open_out fln)
		else 
			()

	let find tst fln =
		let ctest = compile_filter (And(tst,Not(Or(Is_parent_dir,Is_current_dir))))
		in
		let cdir  = compile_filter (And(Is_dir,Not(Or(Is_parent_dir,Is_current_dir))))
		in
		let rec find_simple fln =
			let dir_content = 
				ls fln
			in
			List.fold_left 
				(fun x y -> List.rev_append (find_simple y) x)
				(List.filter ctest dir_content)
				(List.filter cdir  dir_content)
		in
		if test Is_dir fln then
			find_simple fln
		else if ctest fln then
			[fln]
		else
			[]

	let rm ?(force=Force) ?(recurse=false) fln =
		let rm_simple fln =
			let doit = 
				match force with
				  Force -> true
				| Ask ask -> ask fln
			in
			if doit && (test Is_dir fln) then
				try 
					Unix.rmdir fln
				with Unix.Unix_error(Unix.ENOTEMPTY,_,_) ->
					raise RmDirNotEmpty
			else if doit then
				Unix.unlink fln
			else 
				()
		in
		if recurse then
			begin
			List.iter rm_simple (find True fln);
			rm_simple fln
			end
		else
			rm_simple fln

	let cp ?(force=Force) ?(recurse=false) fln_src fln_dst = 
		let cwd = Sys.getcwd ()
		in
		let cp_simple fln_src fln_dst =
			let doit = 
				(* We do not accept to copy a file over himself *)
				(* Use reduce to get rid of trick like ./a to a *)
				(
					reduce fln_src <> reduce fln_dst
				)
				&&
				(
					if test Exists fln_dst then
						match force with
						  Force -> true
						| Ask ask -> ask fln_dst
					else
						true
				)
			in
			if doit then
				match stat_type fln_src with
				  File -> 
					begin
						let buffer_len = 1024
						in
						let buffer = String.make buffer_len ' '
						in
						let read_len = ref 0
						in
						let ch_in = open_in_bin fln_src
						in
						let ch_out = open_out_bin fln_dst
						in
						while (read_len := input ch_in buffer 0 buffer_len; !read_len <> 0 ) do
							output ch_out buffer 0 !read_len
						done;
						close_in ch_in;
						close_out ch_out
					end
				| Dir ->
					mkdir fln_dst
				(* We do not accept to copy this kind of files *)
				(* It is too POSIX specific, should not be     *)
				(* implemented on other platform               *)
				| Link 
				| Fifo 
				| Dev_char 
				| Dev_block
				| Socket ->
					raise CpCannotCopy
			else
				()
		in
		let cp_dir () = 
			let fln_src_abs = (make_absolute cwd fln_src)
			in
			let fln_dst_abs = (make_absolute cwd fln_dst)
			in
			let fln_src_lst = (find True fln_src_abs)
			in
			let fln_dst_lst = List.map 
				(fun x -> make_absolute fln_dst_abs (make_relative fln_src_abs x))
				fln_src_lst
			in
			List.iter2 cp_simple fln_src_lst fln_dst_lst
		in
		match (test Is_dir fln_src, test Is_dir fln_dst, recurse) with
		  ( true, true, true) ->
			cp_dir ()
		| ( true, true,false) ->
			raise CpCannotCopyDirToDir
		| ( true,false, true) ->
			if test Exists fln_dst then
				raise CpCannotCopyDirToFile
			else
				(mkdir fln_dst; cp_dir ())
		| ( true,false,false) ->
			raise CpCannotCopyDirToDir
		| (false, true, true) 
		| (false, true,false) ->
			if test Exists fln_src then
				let fln_src_abs = make_absolute cwd fln_src
				in
				let fln_dst_abs = make_absolute cwd fln_dst
				in
				cp_simple 
					fln_src_abs 
					( make_absolute fln_dst_abs (basename fln_src_abs) )
		| (false,false, true) 
		| (false,false,false) ->
			if (test Exists fln_src) then
				cp_simple 
					(make_absolute cwd fln_src) 
					(make_absolute cwd fln_dst)
			else 
				raise CpNoSourceFile

	let rec mv ?(force=Force) fln_src fln_dst =
		let cwd = Sys.getcwd ()
		in
		let fln_src_abs =  make_absolute cwd fln_src
		in
		let fln_dst_abs =  make_absolute cwd fln_dst
		in
		if fln_src_abs <> fln_dst_abs then
		begin
			if test Exists fln_dst_abs then
			begin
				let doit = 
					match force with
					  Force -> true
					| Ask ask -> ask fln_dst
				in
				if doit then
				begin
					rm fln_dst_abs;
					mv fln_src_abs fln_dst_abs
				end
				else
					()
			end
			else if test Is_dir fln_dst_abs then
				mv ~force:force 
					fln_src_abs
					(make_absolute fln_dst_abs (basename fln_src_abs))
			else if test Exists fln_src_abs then
				Sys.rename fln_src_abs fln_src_abs
			else
				raise MvNoSourceFile
		end
		else
			()
end
;;


(** {1 Concrete file utilities } *)

(** Implementation using regexp *)
module StrUtil : FILE_UTILS = GenericUtil(struct 
	type t = Str.regexp
	let  compile = Str.regexp
	let  test    = fun r x -> Str.string_match r x 0
end)
;;