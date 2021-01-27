
(* Note: this file is modified from the Caml Light 7.1
 * distribution.  Does the above copyright apply?
 *)
include Queue

let to_list q =
  let l = ref [] in
  iter (fun it ->
    l := it :: !l
  ) q ;
  List.rev !l

let to_array q =
  let len = length q in
  if len = 0 then (
    [||]
  ) else (
    let a = Array.make len (take q) in
    (* Don't forget to skip the first one.
     *)
    for i = 1 to pred len do
      a.(i) <- take q
    done ;
    a
  )

let rec clean f q =
  match take_opt q with
  | None -> ()
  | Some v -> f v ; clean f q

