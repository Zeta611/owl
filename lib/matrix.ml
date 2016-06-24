(** [
  Wrap up Lacaml module
  Note: Fortran layout column-based matrix
  The layout is really important, can impact the performance greatly!
  ]  *)

module LC = Lacaml
module LL = Lacaml.D
module LM = LL.Mat

type area = { a : int; b : int; c : int; d : int }

module Matrix = struct

  (* matrix creation operations *)

  let make = LM.make

  let zeros = LM.make0

  let ones m n = make m n 1.

  let eye = LM.identity

  let random = LM.random

  let vector x = make x 1

  let vector_ones x = vector x 1.

  let vector_zeros x = vector x 0.

  let vector_random = random 1

  let empty = LM.empty

  (* matrix manipulations *)

  let size x = LM.dim1 x, LM.dim2 x

  let shape = size

  let same_shape x1 x2 = size x1 = size x2

  let area a b c d = { a = a; b = b; c = c; d= d }

  let area_of x =
    let m, n = size x in
    { a = 1; b = 1; c = m; d= n }

  let equal_area r1 r2 =
    ((r1.c-r1.a = r2.c-r2.a) && (r1.d-r1.b = r2.d-r2.b))

  let same_area r1 r2 = r1 = r2

  let copy_area_to x1 r1 x2 r2 =
    LL.lacpy ~ar:(r1.a) ~ac:(r1.b) ~br:(r2.a) ~bc:(r2.b)
      ~m:(r1.c-r1.a+1) ~n:(r1.d-r1.b+1) ~b:x2 x1

  let copy_to x1 x2 =
    copy_area_to x1 (area_of x1) x2 (area_of x2)

  let ( >> ) = copy_to

  let ( << ) x1 x2 = copy_to x2 x1

  let concat_vertical x1 x2 =
    let r1, r2 = area_of x1, area_of x2 in
    let _ = assert (r1.d = r2.d) in
    let r3 = area (r1.c + 1) 1 (r1.c + r2.c) r1.d in
    let x3 = zeros (r1.c + r2.c) r1.d in
    let _ = copy_area_to x1 r1 x3 r1 in
    let _ = copy_area_to x2 r2 x3 r3 in
    x3

  let ( @= ) = concat_vertical

  let concat_horizontal x1 x2 =
    let r1, r2 = area_of x1, area_of x2 in
    let _ = assert (r1.c = r2.c) in
    let r3 = area 1 (r1.d + 1) r1.c (r1.d + r2.d) in
    let x3 = zeros r1.c (r1.d + r2.d) in
    let _ = copy_area_to x1 r1 x3 r1 in
    let _ = copy_area_to x2 r2 x3 r3 in
    x3

  let ( @|| ) = concat_horizontal

  let fill_area x v r =
    LM.fill ~ar:(r.a) ~ac:(r.b) ~m:(r.c-r.a+1) ~n:(r.d-r.b+1) x v

  let fill x v = fill_area x v (area_of x)

  let transpose x = LL.Mat.transpose_copy x

  let numel x =
    let m, n = size x in
    m * n

  let row_num x = fst (size x)

  let col_num x = snd (size x)

  let part x r =
    let a, b, c, d = r.a, r.b, r.c, r.d in
    LL.lacpy ~ar:a ~ac:b ~m:(c-a+1) ~n:(d-b+1) x

  let duplicate x =
    let m, n = size x in
    let r = area 1 1 m n in
    part x r

  let col x i =
    let m, n = size x in
    let r = area 1 i m i in
    part x r

  let row x i =
    let m, n = size x in
    let r = area i 1 i n in
    part x r

  let _get_content_dim x l dim =  (* dim = 0 for rows; 1 for cols *)
    let m, n = size x and c = List.length l in
    let area_at i = if dim = 0 then area i 1 i n
      else area 1 i m i in
    let a, b = if dim = 0 then (c, n) else (m, c) in
    let y = zeros a b in
    List.iteri (fun i j ->
      let _ = copy_area_to x (area_at j) y (area_at i) in ()
    ) l; y

  let cols x l = _get_content_dim x l 1

  let rows x l = _get_content_dim x l 0

  let diag x =
    let v = LM.copy_diag x in
    LM.from_col_vec v

  let trace x = LM.trace

  (* matrix iteration operations *)

  let iteri f x =
    let m, n = size x in
    for j = 1 to n do
      for i = 1 to m do
        f i j x.{i,j}
      done
    done

  let iter f x = iteri (fun _ _ y -> f y) x

  let _iteri_dim bound_fun get_fun f x =
    for i = 1 to (bound_fun x) do
      f i (get_fun x i)
    done

  let iteri_rows f x = _iteri_dim row_num row f x

  let iter_rows f x = iteri_rows (fun _ y -> f y) x

  let iteri_cols f x = _iteri_dim col_num col f x

  let iter_cols f x = iteri_cols (fun _ y -> f y) x

  let map f x = LM.map f x

  let mapi f x =
    let y = zeros (row_num x) (col_num x) in
    let _ = iteri (fun i j z -> y.{i,j} <- f i j z) x in y

  let mapi_rows f x =
    let r = ref [] in
    iteri_rows (fun i y -> r := !r @ [f i y]) x; !r

  let map_rows f x = mapi_rows (fun _ y -> f y) x

  let mapi_cols f x =
    let r = ref [] in
    iteri_cols (fun i y -> r := !r @ [f i y]) x; !r

  let map_cols f x = mapi_cols (fun _ y -> f y) x

  let filteri f x =
    let r = ref [ ] in
    let _ = iteri (fun i j y ->
      if (f i j y) = true then r := !r @ [(i,j)]
    ) x in !r

  let filter f x = filteri (fun _ _ y -> f y) x

  let _filteri_dim iter_fun f x =
    let r = ref [ ] in
    let _ = iter_fun (fun i v ->
      if (f i v) = true then r := !r @ [i]
    ) x in !r

  let filteri_rows f x = _filteri_dim iteri_rows f x

  let filter_rows f x = filteri_rows (fun _ y -> f y) x

  let filteri_cols f x = _filteri_dim iteri_cols f x

  let filter_cols f x = filteri_cols (fun _ y -> f y) x

  (* folding is always up->down and left->right order. *)
  let _fold_raw iter_fun f a x =
    let r = ref a in
    iter_fun (fun y -> r := f !r y) x; !r

  let fold f a x = _fold_raw iter f a x

  let fold_rows f a x = _fold_raw iter_rows f a x

  let fold_cols f a x = _fold_raw iter_cols f a x

  let exists f x =
    try iter (fun y ->
      if (f y) = true then failwith "found"
    ) x; false
    with exn -> true

  let not_exists f x = not (exists f x)

  let for_all f x = let g y = not (f y) in not_exists g x

  (* matrix mathematical operations *)

  let add x1 x2 = LM.add x1 x2
  let ( +@ ) = add

  let sub x1 x2 = LM.sub x1 x2
  let ( -@ ) = sub

  let dot x1 x2 = LL.gemm x1 x2
  let ( $@ ) = dot

  let mul x1 x2 = LM.mul x1 x2
  let ( *@ ) = mul

  let div x1 x2 = LM.div x1 x2
  let ( /@ ) = div

  let abs x = LM.abs x

  let neg x = LM.neg x

  let sum x = LM.sum x

  let sum_cols x =
    let y = ones (col_num x) 1 in
    dot x y

  let sum_rows x =
    let y = ones 1 (row_num x) in
    dot y x

  let is_equal x1 x2 = for_all (( = ) 0.) (sub x1 x2)

  let ( =@ ) = is_equal

  let is_greater x1 x2 = for_all (( < ) 0.) (sub x1 x2)

  let ( >@ ) = is_greater

  let is_smaller x1 x2 = for_all (( > ) 0.) (sub x1 x2)

  let ( <@ ) = is_smaller

  let equal_or_greater x1 x2 = for_all (( <= ) 0.) (sub x1 x2)

  let ( >=@ ) = equal_or_greater

  let equal_or_smaller x1 x2 = for_all (( >= ) 0.) (sub x1 x2)

  let ( <=@ ) = equal_or_smaller

  let min = fold min max_float

  let min_col = map_cols min

  let min_row = map_rows min

  let max = fold max min_float

  let max_col = map_cols max

  let max_row = map_cols max

  let ( +$ ) x a = map (fun y -> y +. a) x

  let ( $+ ) a x = ( +$ ) x a

  let ( -$ ) x a = map (fun y -> y -. a) x

  let ( $- ) a x = ( -$ ) x a

  let ( *$ ) x a = map (fun y -> y *. a) x

  let ( $* ) a x = ( *$ ) x a

  let ( /$ ) x a = map (fun y -> y /. a) x

  let ( $/ ) a x = ( /$ ) x a

  (* advanced matrix methematical operations *)

  let detri x = LM.detri x  (* TODO: refine this *)

  let lu x = LL.getrf

  let qr x = LM.from_col_vec (LL.geqrf x) (* TODO: refine this *)

  let cholesky = LL.potrf

  let svd x = LL.gesvd x (* TODO: refine this *)

  let inv x = LL.getri x

  let least_square = LL.gels (* TODO: refine this *)

  (* formatted input / output operations *)

  let pprint x = Format.printf "%a\n" LL.pp_mat x

  let pprint_header = None

  let dump x f =
    let h = open_out f in
    iter_rows (fun y ->
      iter (fun z -> Printf.fprintf h "%f " z) y;
      Printf.fprintf h "\n"
    ) x;
    close_out h

  let load f = None

  (* transform to or from other types *)

  let to_list = LM.to_list

  let to_array = LM.to_array

  let of_list = LM.of_list

  let of_array = LM.of_array

  (* other functions *)

 let sequential m n =
   let x = zeros m n and c = ref 0 in
   let _ = iteri (fun i j _ ->
     let _ = c := !c + 1 in
     x.{i,j} <- (float_of_int !c)
   ) x in x

end;;

module M = Matrix;;
