(**************************************************************)
(* SOCKSUPP.MLI *)
(* Ohad Rodeh : 10/2002                                    *)
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

val max_msg_size : int
val some_of : 'a option -> 'a

exception Out_of_iovec_memory
