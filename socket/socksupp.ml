(**************************************************************)
(* SOCKSUPP.ML *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)

type buf = bytes
type len = int
type ofs = int
type socket = Unix.file_descr

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

type mcast_send_recv = 
  | Recv_only
  | Send_only
  | Both

(**************************************************************)
let some_of = function 
  | Some x -> x 
  | None -> failwith "sanity"

(**************************************************************)
let max_msg_size = 8 * 1024
(**************************************************************)
exception Out_of_iovec_memory
(**************************************************************)
