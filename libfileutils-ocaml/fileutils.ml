(* Des fonctions generique pour tester l'existence ... *)
(* Elles gerent en plus la disponibilite du fichier *)

let (current_dir_name, parent_dir_name, concat, is_relative, 
	is_implicit, check_suffix, chop_suffix, chop_extension,
	basename, dirname, temp_file, open_temp_file, quote) = 
	(Filename.current_dir_name, Filename.parent_dir_name,
	Filename.concat, Filename.is_relative, Filename.is_implicit,
	Filename.check_suffix, Filename.chop_suffix,
	Filename.chop_extension, Filename.basename, Filename.dirname,
	Filename.temp_file, Filename.open_temp_file, Filename.quote)

type fs_type = 
	Dir  
	| File 
	| Dev_char
	| Dev_block
	| Link
	| Fifo
	| Socket
	| Unknown
;;	

let stat filename =
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
		Unknown 
		
;;

let right_dir = [ Unix.R_OK ; Unix.F_OK ; Unix.X_OK ]
;;

let right_normal = [ Unix.R_OK ; Unix.F_OK ]
;;

let test_right fln rgt =
	try
		Unix.access fln rgt;
 		true
	with Unix.Unix_error(_) ->
		false
;;

type test_file =
	Is_file 
	| Is_dir
	| Is_link
	| And of test_file * test_file
	| Or of test_file * test_file
	| Not of test_file
;;

let rec compile_filter flt =
	match flt with
	Is_file ->
		begin
		fun x -> match stat x with 
			File -> test_right x right_normal 
			| _ -> false
		end
	| Is_dir -> 
		begin
		fun x -> match stat x with 
			Dir -> test_right x right_dir 
			| _ -> false
		end
	| Is_link ->
		begin			
		fun x -> match stat x with 
			Link -> test_right x right_normal 
			| _ -> false
		end
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
;;

exception Base_path_relative;;
exception Path_relative_unreducable;;

let check_base_path path =
	if is_relative path then
		raise Base_path_relative
	else
		()
;; 

let implode path =
	match path with 
	"" :: tl_lst ->
		List.fold_left 
			(concat) 
			"/"
			tl_lst	
	| _ ->
		List.fold_left 
			(concat) 
			""
			path
	
;;

let rec explode path =
	let rec sub_path start s = 
		try
			let next_sep = String.index_from s start '/'
			in
			let component = (String.sub s start (next_sep - start)) 
			in
			(component :: sub_path (next_sep+1) s)
		with Not_found ->
			begin
			match (String.length s)-start with
			0 ->
				[]
			| x -> 
				String.sub s start x :: []
			end
	in
	sub_path 0 path
;;

let rec reduce_list path_lst =
	match path_lst with
	fst :: snd :: thd :: tl_lst 
		when thd = parent_dir_name ->
			reduce_list (fst :: tl_lst)
	| fst :: snd :: tl_lst 
		when snd = current_dir_name ->
			reduce_list (fst :: tl_lst)
	| fst :: tl_lst ->
		fst :: (reduce_list tl_lst)
	| [] ->
		[]
;;

let reduce path =
	if is_relative path then
		raise Path_relative_unreducable
	else
		implode (reduce_list (explode path))
;;

let make_absolute_list lst_base lst_path =
	reduce_list (lst_base @ lst_path)
;;

let make_absolute base_path path =
	if is_relative path then
		begin
		let list_absolute =
			check_base_path base_path;
			make_absolute_list 
				(reduce_list (explode base_path))
				(explode base_path)
		in
		implode list_absolute
		end
	else
		path
;;

let rec make_relative_list lst_base lst_path =
	match  (lst_base, lst_path) with
	x :: tl_base, a :: tl_path when x = a ->
		make_relative_list tl_base tl_path
	| _, _ ->
		let back_to_base = List.rev_map 
			(fun x -> parent_dir_name)
			lst_base
		in
		back_to_base @ lst_path
;;

let make_relative base_path path =
	if is_relative path then
		path
	else
		begin
		let list_relative =
			check_base_path base_path;
			make_relative_list 
				(reduce_list (explode base_path))
				(reduce_list (explode path))
		in
		implode list_relative
		end
;;


let list_dir dirname =
	let hdir = Unix.opendir dirname
	in
	let rec list_dir_aux lst =
		try
			let filename = Unix.readdir hdir
			in
			let complete_path = 
				concat dirname filename
			in
			list_dir_aux (complete_path :: lst)
		with End_of_file ->
			Unix.closedir hdir;
			lst
	in
	list_dir_aux []
;;	


let filter_dir flt lst =
	let cflt = compile_filter flt
	in
	List.filter cflt lst
;;

let test tst fln =
	let ctst = compile_filter tst
	in
	ctst fln 
;;	
