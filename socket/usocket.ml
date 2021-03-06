(**************************************************************)
(* USOCKET *)
(* Author: Mark Hayden, 4/97 *)
(* Massive changes: Ohad Rodeh 10/2001 *)
(**************************************************************)
let name = "USOCKET"
let failwith s = failwith (name^":"^s)
(**************************************************************)
open Printf
(**************************************************************)
type buf = bytes
type ofs = int
type len = int
type socket = Unix.file_descr
type timeval = Socksupp.timeval = {
  mutable sec10 : int ;
  mutable usec : int
}

exception Out_of_iovec_memory = Socksupp.Out_of_iovec_memory

let max_msg_size = Socksupp.max_msg_size

(**************************************************************)

let verbose = ref false

let set_verbose flag =
  verbose := flag

let log f = 
   if !verbose then print_endline (f ())

(* An unoptimized version of the iovec
*)
module Iov = struct 
  (* The type of a C memory-buffer. It is opaque.
   * Here, it is simply an ML string. A cheap hack indeed. 
   *)
  type t = bytes

  type pool = int

  (* type iovec = bytes *)

  let init verbose chunk_size max_mem_size send_pool_size min_alloc_size incr_step = 
    set_verbose verbose

  let get_send_pool () = 0
  let get_recv_pool () = 0

  let shutdown () = () 

  (*
  let t_of_iovec x = x
  let iovec_of_t x = x *)

  let bytes_of_t x = x
  let bytes_of_t_full s ofs iov = Bytes.blit iov 0 s ofs (Bytes.length iov)
  let t_of_string pool x ofs len =
     let buf = Bytes.create len in
        Bytes.blit_string x ofs buf 0 len;
        buf
    
  let len iov = Bytes.length iov

  let empty = Bytes.empty

  (* let try_alloc size = Bytes.create size *)

  let alloc_async pool size cont_fun = cont_fun (Bytes.create size)

  let alloc pool size = Bytes.create size

  let satisfy_pending () = ()

  let sub t ofs len = Bytes.sub t ofs len
    
  let free _ = ()
    
  let copy t = t
    
  (* Compute the total length of an iovec array.
   *)
  let iovl_len iovl = Array.fold_left (fun pos iov -> 
    pos + len iov
  ) 0 iovl

  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   *
   * [flatten iov len] 
   * [len] is the length of the iovl.
   *)
  let flatten_w_copy ta = 
    let total_len = iovl_len ta in
    let s = Bytes.create total_len in
    let sum = ref 0 in
    for i=0 to pred (Array.length ta) do
      let len = Bytes.length ta.(i) in
      Bytes.blit ta.(i) 0 s !sum len;
      sum := !sum + len;
    done;
    s

  let flatten ta =  
    if Array.length ta = 1 then ta.(0)
    else flatten_w_copy ta

  (* Return a bogus value.
   *)
  let num_refs _ = (-1)

  let marshal pool obj flags = Marshal.to_bytes obj flags

  let unmarshal iov = Marshal.from_bytes iov 0

  let get_stats () = "ML-heap"
end

let flatten = Iov.flatten
let empty = Iov.empty

(**************************************************************)

let linux_warning =
  let warned = ref false in
  fun () ->
    if not !warned then (
      warned := true ;
      print_endline "USOCKET:warning:working around a Linux error" ;
      print_endline "USOCKET:see ensemble/BUGS for more information" ;
    )

(**************************************************************)

(* Wrapper for system calls so that they will ignore a group
 * of errors that we don't care about.
 *)
let unix_wrap debug f =
  try f () with Unix.Unix_error(err,s1,s2) as exc ->
    match err with 
    | Unix.ECONNREFUSED 
    | Unix.ECONNRESET 
    | Unix.EHOSTDOWN			(* This was reported on SGI *)
    | Unix.ENOENT			(* This was reported on Solaris *)
    | Unix.ENETUNREACH
    | Unix.EHOSTUNREACH			(* FreeBSD *)
    | Unix.EPIPE 
    | Unix.EINTR			(* Should this be here? *)
    | Unix.EAGAIN -> 
(*	log (fun () -> "SOCKSUPP:warning:"^debug^":"^(Unix.error_message err)^":"^s1^":"^s2) ;*)
	0
    | _ ->
	print_endline ("SOCKSUPP:"^debug^":"^(Unix.error_message err)) ;
	raise exc


(**************************************************************)

type sendto_info = Unix.file_descr * Unix.sockaddr array

 (*
let string_of_info (_,sa) = 
  String.concat ":" (Array.to_list (Array.map (function
      Unix.ADDR_UNIX _ -> ""
    | Unix.ADDR_INET (inet,port) -> 
	sprintf "%s,%d" (Unix.string_of_inet_addr inet) port
  ) sa)) *)


(**************************************************************)

(* These are no-ops in the windows Unix library.
 *)

let setsockopt_nonblock s b =
  if b then 
    Unix.set_nonblock s 
  else 
    Unix.clear_nonblock s

(**************************************************************)
let stdin () = Unix.stdin
let read = Unix.read
let sendto_info s a = (s,a)
(* let send_info s = s *)
let has_ip_multicast () = false
let in_multicast _ = failwith "in_multicast"
let setsockopt_ttl _ _ = failwith "setsockopt_multicast"
let setsockopt_loop _ _ = failwith "setsockopt_loop"

type mcast_send_recv = Socksupp.mcast_send_recv = 
  | Recv_only
  | Send_only
  | Both

let setsockopt_join _ _ = failwith "setsockopt_join"
let setsockopt_leave _ _ = failwith "setsockopt_leave"
let setsockopt_sendbuf _ _ = failwith "setsockopt_sendbuf"
let setsockopt_recvbuf _ _ = failwith "setsockopt_recvbuf"
let setsockopt_bsdcompat _ _ = failwith "setsockopt_bsdcompat"
let setsockopt_reuse sock onoff = Unix.setsockopt sock Unix.SO_REUSEADDR onoff
external int_of_file_descr : Unix.file_descr -> int = "%identity"
let int_of_socket = int_of_file_descr
let socket = Unix.socket

let socket_mcast = Unix.socket 
let connect = Unix.connect
let bind = Unix.bind
let close = Unix.close
let listen =Unix.listen
let accept = Unix.accept
(**************************************************************)

(*
type md5_ctx = string list ref

let md5_init () = ref []

let md5_init_full init_key = ref [init_key]

let md5_update ctx buf ofs len =
  ctx := (Bytes.sub buf ofs len) :: !ctx

let md5_update_iov ctx str =
  ctx := str :: !ctx

let md5_final ctx =
  let ctx = List.rev !ctx in
  let s = String.concat "" ctx in
(*
  eprintf "MD5_FINAL:%s\n" (hex_of_string s) ;
  eprintf "MD5_FINAL:%d\n" (Bytes.length s) ;
*)
  Digest.string s
*)

(**************************************************************)

let gettimeofday tv =
  let time = Unix.gettimeofday () in
  let usec,sec10 = modf (time /. 10.) in
  let usec = usec *. 1.0E7 in
  tv.sec10 <- truncate sec10 ;
  tv.usec <- truncate usec ;
  if tv.usec < 0 || tv.usec >= 10000000 then
    failwith "gettimeofday:bad usec value"

(**************************************************************)
(* From util.ml
let word_len = 4
let mask1 = pred word_len
let mask2 = lnot mask1
let ceil_word i = (i + mask1) land mask2 *)
(**************************************************************)
(* The total length of an Iovecl.
*)
let iovecl_len iovl = 
  Array.fold_left (fun acc iov -> 
    acc + Iov.len iov 
  ) 0 iovl

(**************************************************************)
(* Send/Recv functions for TCP.
*)
let tcp_recv s b o l = Unix.recv s b o l []
let tcp_recv_iov s b o l = Unix.recv s b o l []

let tcp_recv_packet sock hdr ofs len iov =
  let recv_len = len + Iov.len iov in
  let recv_buf = Bytes.create recv_len in
  log (fun () -> sprintf "recv_len=%d" recv_len);
  let got_len = Unix.recv sock recv_buf 0 recv_len [] in
  Bytes.blit recv_buf 0 hdr ofs len;
  Bytes.blit recv_buf len iov 0 (Iov.len iov);
  got_len

(**************************************************************)
(* This function is modified to repeat calls that return
 * ECONNREFUSED.  See ensemble/BUGS for more information.
 *)

let udp_send (s,a) b o l = 
  for i = 0 to pred (Array.length a) do
    try
      ignore (Unix.sendto s b o l [] a.(i))
    with e ->
      match e with 
      | Unix.Unix_error(Unix.ECONNREFUSED,_,_) ->
	  linux_warning () ;
	  ignore (unix_wrap "sendto(2nd)" (fun () -> Unix.sendto s b o l [] a.(i)))
      | _ -> 
	  ignore (unix_wrap "sendto(1st)" (fun () -> raise e))
  done


let write_int32 = Bytes.set_int32_be
    
let read_int32 = Bytes.get_int32_be
    
let prepare_header ml_len usr_len = 
  let s = Bytes.create 8 in
  write_int32 s 0 (Int32.of_int ml_len);
  write_int32 s 4 (Int32.of_int usr_len);
  s

let udp_mu_sendsv info buf ofs len iovl = 
(*  log (fun () -> sprintf "sendtosv %s\n" (string_of_info info));*)
  let hdr = prepare_header len (iovecl_len iovl) in
  let iovl = Array.append [|hdr; Bytes.sub buf ofs len|] iovl in
  let str = flatten iovl in
  udp_send info str 0 (Bytes.length str)
  

(* Send/Recv functions for TCP.
 * Exceptions are thrown, and the length of data
 * actually sent is returned. 
 * The header is constructed by Hsyssupp.
*)
let tcp_send s buf ofs len = Unix.send s buf ofs len []

let tcp_sendv s iovl = 
  log (fun () -> "sendv_p") ;
  let buf = flatten iovl in
   Unix.send s buf 0 (Bytes.length buf) []

let tcp_sendsv s buf ofs len iovl = 
  let iovl = Array.append [|Bytes.sub buf ofs len|] iovl in
  let buf = flatten iovl in
  log (fun () -> sprintf "sendsv_p (len=%d)" (Bytes.length buf)) ;
  Unix.send s buf 0 (Bytes.length buf) []

let tcp_sends2v s buf1 buf2 ofs2 len2 iovl = 
  let iovl = Array.append [|buf1; Bytes.sub buf2 ofs2 len2|] iovl in
  let buf = flatten iovl in
  log (fun () -> sprintf "sendsv2_p (len=%d)" (Bytes.length buf)) ;
  Unix.send s buf 0 (Bytes.length buf) []

(* A context structure.
*)
(* type digest = string (* A 16-byte string *) *)

let recvfrom s b o l = Unix.recvfrom s b o l []

let udp_mu_recv_packet pool sock mlbuf= 
  try 
    (* NT requires recvfrom for non-connected sockets.
     *)
     let len = Unix.recv sock mlbuf 0 max_msg_size []
     in
        if len = max_msg_size then
           (eprintf "USOCKET:udp_recv_packet:warning:got packet that is maximum size (probably truncated), dropping (len=%d)\n%!" len;
            0,empty)
        else
           let hdr_len = Int32.to_int (read_int32 mlbuf 0) in
           let iovec_len = Int32.to_int (read_int32 mlbuf 4) in
              if 8+hdr_len+iovec_len <> len then
                 0,empty
              else (
                      (*log (fun () -> sprintf "udp_recv_packet, hdr=%d iovl=%d\n" hdr_len iovec_len); *)
                      let iovec = Bytes.sub mlbuf (8+hdr_len) (len-hdr_len-8) in
                         hdr_len, iovec
                   )
  with Unix.Unix_error(e,_,_) as exn -> 
    match e with 
	Unix.EPIPE
      | Unix.EINTR
      | Unix.EAGAIN
      | Unix.ECONNREFUSED
      | Unix.ECONNRESET
      | Unix.ENETUNREACH
      | Unix.EHOSTDOWN
      | Unix.EISCONN
      | Unix.EMSGSIZE -> 0,empty
      | _ -> raise exn

(**************************************************************)

let rec substring_eq_help s1 o1 s2 o2 l i =
  if i >= l then true 
  else if Bytes.get s1 (i+o1) = Bytes.get s2 (i+o2) then
    substring_eq_help s1 o1 s2 o2 l (succ i)
  else false

let substring_eq s1 o1 s2 o2 l =
  let l1 = Bytes.length s1 in
  let l2 = Bytes.length s2 in
  if l < 0 then failwith "substring_eq:negative length" ;
  if o1 < 0 || o2 < 0 || o1 + l > l1 || o2 + l > l2 then
    failwith "substring_eq:range out-of-bounds" ;
  substring_eq_help s1 o1 s2 o2 l 0

(**************************************************************)

type sock_info = (Unix.file_descr array) * (bool array)
type fd_info = sock_info * (Unix.file_descr list)
type select_info = fd_info * fd_info * fd_info

let sihelp (socks,ret) =
  ((socks,ret),(Array.to_list socks))

let select_info a b c = 
  let a = sihelp a in
  let b = sihelp b in
  let c = sihelp c in
  (a,b,c)

let select_help (socks,ret) out =
  for i = 0 to pred (Array.length socks) do
    (* We use memq here so that on Nt the equality will
     * not fail when in hits the Abstract tag.
     *)
    ret.(i) <- List.memq socks.(i) out
  done

let string_of_list     f l = sprintf "[%s]" (String.concat "|" (List.map f l))
let string_of_int_list l = string_of_list string_of_int l
let string_of_fd_list  l = string_of_int_list (List.map int_of_file_descr l)
  
let select (a,b,c) timeout =
  let timeout =
    ((float timeout.sec10) *. 10.) +. ((float timeout.usec) /. 1.0E6)
  in
  let a',b',c' =
    let rec loop a b c d =
      try Unix.select a b c d with
      | Unix.Unix_error(Unix.EINTR,_,_) -> 
	  eprintf "USOCKET:select:ignoring EINTR error\n" ;
	  loop a b c d
      | Unix.Unix_error(err,s1,s2) ->(
	  if a=[] && b = [] && c=[] then [],[],[]
	  else begin
      	    eprintf "USOCKET:select:%s\n" (Unix.error_message err) ;
            failwith (sprintf "error calling select a=%s b=%s c=%s"
	      (string_of_fd_list a)
	      (string_of_fd_list b)
	      (string_of_fd_list c))
	    end
	  )
    in loop (snd a) (snd b) (snd c) timeout 
  in
  select_help (fst a) a' ;
  select_help (fst b) b' ;
  select_help (fst c) c' ;
  List.length a' + List.length b' + List.length c'

let time_zero = {sec10=0;usec=0}
let poll si = select si time_zero

(**************************************************************)

(* These are not supported at all.
 *)

(* let terminate_process _ = failwith "terminate_proces"
let heap _ = failwith "heap"
let frames _ = failwith "frames"
let addr_of_obj _ = failwith "addr_of_obj"
let minor_words () = (-1)
*)
(**************************************************************)

