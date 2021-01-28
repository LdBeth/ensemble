module Socket : sig
  (**************************************************************)
  (* SOCKET.MLI *)
  (* Authors: Robbert vanRenesse and Mark Hayden, 4/95  *)
  (* Ohad Rodeh :                                       *)
  (*         C-Memory mangement support          9/2001 *)
  (*         Winsock2 support                   11/2001 *)
  (*         Rewrite                            12/2003 *)
  (**************************************************************)
  val max_msg_size : int
  
  type socket = Unix.file_descr
  type buf = bytes
  type ofs = int
  type len = int
  
  type timeval = {
    mutable sec10 : int ;
    mutable usec : int
  }
  
  (* Set the verbosity level
  *)
  val set_verbose : bool -> unit
  
  exception Out_of_iovec_memory
  
  module Iov : sig 
    (* The type of a C memory-buffer. It is opaque.
     *)
    type t 
  
    type pool
  
    (* initialize the memory-manager. 
     * [init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step]
     *)
    val init : bool -> int -> int -> float -> int -> int -> unit
      
    (* Release all the memory used, assuming none is allocated *)
    val shutdown : unit -> unit
  
    (* The pool of sent-messages *)
    val get_send_pool : unit -> pool
      
    (* The pool of recv-messages *)
    val get_recv_pool : unit -> pool
  
    (* allocation, and copy. 
     *)
    val bytes_of_t : t -> bytes
    val bytes_of_t_full : bytes -> len -> t -> unit
    val t_of_string : pool -> string -> ofs -> len -> t
      
    val len : t -> int
  
    val empty : t 
  
    val alloc_async : pool -> len -> (t -> unit) -> unit
  
    val alloc : pool -> len -> t
  
    val satisfy_pending : unit -> unit
  
    val sub : t -> ofs -> len -> t
      
    (* Decrement the refount, and free the cbuf if the count
     * reaches zero. 
     *)
    val free : t -> unit 
      
    (* Increment the refount, do not really copy. 
     *)
    val copy : t -> t 
  
    (* Flatten an iovec array into a single iovec.  Copying only
     * occurs if the array has more than 1 non-empty iovec.
     *)
    val flatten : t array -> t
  
    (* For debugging. The number of references to the iovec.
     *)
    val num_refs : t -> int
  
    (* Marshal into a preallocated iovec. Raise's exception if
     * there is not enough space. Returns the marshaled iovec.
     *)
    val marshal : pool -> 'a -> Marshal.extern_flags list -> t
  
    (* Unmarshal directly from an iovec. Raises an exception if there
     * is a problem, and checks for out-of-bounds problems. 
     *)
    val unmarshal : t -> 'a
  
    (* statistics *)
    val get_stats : unit -> string
  
  end
    
  (**************************************************************)
  (* Open a file descriptor for reading from stdin.  This is
   * for compatibility with Windows NT.  See
   * ensemble/socket/stdin.c for an explanation.  
   *)
  val stdin : unit -> socket
  
  (* For reading from stdin.
   *)
  val read : socket -> buf -> ofs -> len -> len
  
  (**************************************************************)
  
  type sock_info = (socket array) * (bool array)
  type select_info
  val select_info : sock_info -> sock_info -> sock_info -> select_info
  
  val select : select_info -> timeval -> int
  val poll : select_info -> int
  
  (**************************************************************)
  
  (* Check if portions of two strings are equal.
   *)
  val substring_eq : bytes -> ofs -> bytes -> ofs -> len -> bool
  
  (**************************************************************)
  (* Optimized transmission functions.  No exceptions are
   * raised.  Scatter-gather used if possible.  No interrupts
   * are serviced during call.  No bounds checks are made.
   *)
  
  val recvfrom : socket -> buf -> ofs -> len -> len * Unix.sockaddr
  
  (* A context structure.
  *)
  type sendto_info
  val sendto_info : socket -> Unix.sockaddr array -> sendto_info
  
  (* The returned length only refers to the last buffer sent. 
   * It is used only when using TCP sockets.
  *)
  val udp_send : sendto_info -> buf -> ofs -> len -> unit
  val udp_mu_sendsv : sendto_info -> buf -> ofs -> len -> Iov.t array -> unit
  
  (* Recv a packet in Ensemble format.  
   * [udp_mu_recv_packet sock prealloc_buf] returns [mllen, iovec]
   * 
   * It attempts to recive a packet where the header will be copied into
   * the preallocated buffer. The bulk data will be allocated inside an
   * iovec. The length of the ml-header is returned.
   *)
  val udp_mu_recv_packet : Iov.pool -> socket -> buf -> len * Iov.t
  
  (* These functions are used in Hsyssupp in receiving 
   * TCP packets. 
   *)
  val tcp_send : socket -> buf -> ofs -> len -> len
  val tcp_sendv : socket -> Iov.t array -> len
  val tcp_sendsv : socket -> buf -> ofs -> len -> Iov.t array -> len
  val tcp_sends2v : socket -> buf -> buf -> ofs -> len -> Iov.t array -> len
  val tcp_recv : socket -> bytes -> ofs -> len -> len
  val tcp_recv_iov : socket -> Iov.t -> ofs -> len -> len
  val tcp_recv_packet : socket -> bytes -> ofs -> len -> Iov.t -> len
  
  (**************************************************************)
  
  (*** Multicast support. *)
  
  (* Return whether this host supports IP multicast. 
   *)
  val has_ip_multicast : unit -> bool 
  
  (* Is this a class D address ?
  *)
  val in_multicast : Unix.inet_addr -> bool
  
  (* Setup the TTL value
   *)
  val setsockopt_ttl : socket -> int -> unit 
  
  (* Setup the loopback switch
   *)
  val setsockopt_loop : socket -> bool -> unit 
  
  (* Join an IP multicast group. 
   *)
  type mcast_send_recv = 
    | Recv_only
    | Send_only
    | Both
  
  val setsockopt_join : socket -> Unix.inet_addr -> mcast_send_recv -> unit 
  
  (* Leave an IP multicast group. 
   *)
  val setsockopt_leave : socket -> Unix.inet_addr -> unit 
  
  (**************************************************************)
  
  (* Set size of sending buffers.
   *)
  val setsockopt_sendbuf : socket -> int -> unit
  
  (* Set size of receiving buffers.
   *)
  val setsockopt_recvbuf : socket -> int -> unit
  
  (* Set socket to be blocking/nonblocking.
   *)
  val setsockopt_nonblock : socket -> bool -> unit
  
  (* Set socket ICMP error reporting.  See sockopt.c.
   *)
  val setsockopt_bsdcompat : socket -> bool -> unit
  
  (* Set the socket to reusable (or not).
  *)
  val setsockopt_reuse : socket -> bool -> unit
  
  (**************************************************************)
  (* MD5 support.
   *
  type md5_ctx
  val md5_init : unit -> md5_ctx
  val md5_init_full : string -> md5_ctx
  val md5_update : md5_ctx -> buf -> ofs -> len -> unit
  val md5_update_iov : md5_ctx -> Iov.t -> unit
  val md5_final : md5_ctx -> Digest.t
  *)
  
  (**************************************************************)
  
  (* HACK!  It's useful to be able to print these out as ints.
   *)
  val int_of_socket : socket -> int
  
  (* On WIN32 we need to use WINSOCK2's calls, instead of
   * regular ones. Since Caml uses WINSOCK1 for maximum portability, we 
   * need to override this for WIN32.
   *)
  val socket : ?cloexec:bool -> Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
  val socket_mcast : ?cloexec:bool -> Unix.socket_domain ->
         Unix.socket_type -> int -> Unix.file_descr
  val connect : Unix.file_descr -> Unix.sockaddr -> unit
  val bind : Unix.file_descr -> Unix.sockaddr -> unit
  
  (* Will work only on sockets on win32.
  *)
  val close : Unix.file_descr -> unit
  
  val listen : Unix.file_descr -> int -> unit
  val accept : ?cloexec:bool -> Unix.file_descr -> Unix.file_descr * Unix.sockaddr
  (**************************************************************)
  
  (* Same as Unix.gettimeofday.  Except that
   * the caller passes in a timeval object that
   * the time is returned in.
   *)
  val gettimeofday : timeval -> unit
  (**************************************************************)
  
  
        
  
    
end

module Trans : sig
  (**************************************************************)
  (* TRANS.MLI *)
  (* Author: Mark Hayden, 12/95 *)
  (**************************************************************)
  
  type mux	= int
  type port	= int
  type incarn	= int
  type vci	= int
  type rank	= int
  type nmembers   = int
  type data_int	= int
  type seqno	= int
  type ltime      = int
  type bitfield	= int
  type fanout     = int
  type name       = string
  type debug      = string
  type inet       = Unix.inet_addr
  type origin     = rank
  type primary    = bool
  type pid        = int
  type location_t = { xloc : float ; yloc : float }
  
  module type OrderedType =
    sig
      type t
      val zero : t
      (*val ge : t -> t -> bool*)
      val ge : t -> t -> bool
      val cmp : t -> t -> int
    end
  
  (**************************************************************)
end

module Util : sig
  (**************************************************************)
  (* UTIL.MLI *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  type ('a,'b,'c) fun2arg = 'a -> 'b -> 'c
  type ('a,'b,'c,'d) fun3arg = 'a -> 'b -> 'c -> 'd
  
  (*
  external arity2 : ('a,'b,'c) fun2arg -> ('a,'b,'c) fun2arg = "%arity2"
  external arity3 : ('a,'b,'c,'d) fun3arg -> ('a,'b,'c,'d) fun3arg = "%arity3"
  *)
  val arity2 : ('a,'b,'c) fun2arg -> ('a,'b,'c) fun2arg
  val arity3 : ('a,'b,'c,'d) fun3arg -> ('a,'b,'c,'d) fun3arg
  
  (**************************************************************)
  (* Really basic things.
   *)
  
  (* The first application creates a counter.  Each time the
   * second unit is applied the next integer (starting from 0)
   * is returned.
   *)
  val counter 		: unit -> unit -> int
  
  (* The identity function.
   *)
  val ident               : 'a -> 'a
  
  (* This is used to discard non-unit return values from
   * functions so that the compiler does not generate a
   * warning.  
   *)
  (*
  val unit : 'a -> unit
  val unit2 : 'a -> 'b -> unit
  *)
  val ignore2 : 'a -> 'b -> unit
  
  val info : string -> string -> string
  
  (* The string sanity.
   *)
  val sanity : string
  val sanityn : int -> string
  
  (**************************************************************)
  (* Debugging stuff.
   *)
  
  val verbose		: bool ref
  val quiet		: bool ref
  val addinfo             : string -> string -> string
  val failmsg             : string -> string -> string
  
  (**************************************************************)
  (* Export printf and sprintf.
   *)
  
  val printf		: ('a, out_channel, unit) format -> 'a
  val eprintf		: ('a, out_channel, unit) format -> 'a
  val sprintf		: ('a, unit, string) format -> 'a
  
  (**************************************************************)
  (* Some list/array operations.
   *)
  
  val sequence		: int -> int array
  val index               : 'a -> 'a list -> int
  val except              : 'a -> 'a list -> 'a list
  val array_is_empty	: 'a array -> bool
  val array_filter	: ('a -> bool) -> 'a array -> 'a array
  val array_index 	: 'a -> 'a array -> int
  val array_mem 	        : 'a -> 'a array -> bool
  val array_filter_nones  : 'a option array -> 'a array
  val array_exists	: (int -> 'a -> bool) -> 'a array -> bool
  val array_incr 		: int array -> int -> unit
  val array_decr 		: int array -> int -> unit
  val array_add           : int array -> int -> int -> unit
  val array_sub           : int array -> int -> int -> unit
  val array_for_all 	: ('a -> bool) -> 'a array -> bool
  val array_flatten       : 'a array array -> 'a array
  val matrix_incr 	: int array array -> int -> int -> unit
  val do_once		: (unit -> 'a) -> (unit -> 'a)
  val hashtbl_size	: ('a,'b) Hashtbl.t -> int
  val hashtbl_to_list     : ('a,'b) Hashtbl.t -> ('a * 'b) list
  val string_check        : debug -> string -> int(*ofs*) -> int(*len*) -> unit
  val deepcopy            : 'a -> 'a
  
  (**************************************************************)
  (* Some string conversion functions.
   *)
  
  val string_of_unit      : unit -> string
  val string_map          : (char -> char) -> string -> string
  val string_of_pair      : 
    ('a -> string) -> ('b -> string) -> ('a * 'b -> string)
  val string_of_list 	: ('a -> string) -> 'a list -> string
  val string_of_array 	: ('a -> string) -> 'a array -> string
  val string_of_int_list 	: int list -> string
  val string_of_int_array : int array -> string
  val bool_of_string      : string -> bool
  val string_of_bool	: bool -> string
  val string_of_bool_list : bool list -> string
  val string_of_bool_array : bool array -> string
  val string_split	: string -> string -> string list
  val hex_to_string	: string -> string
  val hex_of_string	: string -> string
  val strchr              : char -> string -> int
  
  (**************************************************************)
  (* Some additional option operations.
   *)
  
  (* Calls the function if the option is a Some()
   *)
  val if_some 		: 'a option -> ('a -> unit) -> unit
  
  (* Call the function if the option is None.
   *)
  val if_none 		: 'a option -> (unit -> 'a option) -> 'a option
  
  (* Extract the contents of an option.  Fails on None.
   *)
  val some_of 		: debug -> 'a option -> 'a
  
  (* Returns true if the option is None.
   *)
  val is_none 		: 'a option -> bool
  
  (* String representation of an option.
   *)
  val string_of_option 	: ('a -> string) -> 'a option -> string
  val option_map		: ('a -> 'b) -> 'a option -> 'b option
  val filter_nones        : 'a option list -> 'a list
  val once                : debug -> 'a option list -> 'a
  
  (**************************************************************)
  
  val make_magic : unit -> (('a -> Obj.t ) * (Obj.t  -> 'a))
  
  (**************************************************************)
  
  val disable_sigpipe : unit -> unit
  
  (**************************************************************)
  (*
  val average   : int -> unit
  val gc_profile : string -> ('a -> 'b) -> 'a -> 'b
  val gc_profile3 : string -> ('a -> 'b -> 'c -> 'd) -> 'a -> 'b -> 'c -> 'd
  *)
  (**************************************************************)
  
  val strtok : string -> string -> string * string
  
  (**************************************************************)
  
  val string_of_id : debug -> (string * 'a) array -> 'a -> string
  val id_of_string : debug -> (string * 'a) array -> string -> 'a
  
  (**************************************************************)
  
  val string_list_of_gc_stat : Gc.stat -> string list
  
  (**************************************************************)
  (* Get the tag value of an object's representation.
   *)
  
  val tag : 'a -> int
  
  (**************************************************************)
  
  val sample : int -> 'a array -> 'a array
  
  (**************************************************************)
  
  (* Generate a string representation of an exception.
   *)
  val error : exn -> string
  
  (* Same as Printexc.catch.
   *)
  val catch : ('a -> 'b) -> 'a -> 'b
  
  val count_true : bool array -> int
  
  (* Called to set a function for logging information about
   * this module.
   *)
  val set_error_log : ((unit -> string) -> unit) -> unit
  
  val install_error : (exn -> string) -> unit
  (**************************************************************)
  
end

module Queuee : sig
  
  (* Note: this file is modified from the Caml Light 7.1
   * distribution.  Does the above copyright apply?
   *)
  
  (* Queues *)
  
  type 'a t
  
  exception Empty
  
  val create : unit -> 'a t
  (** Return a new queue, initially empty. *)
  
  val add : 'a -> 'a t -> unit
  (** [add x q] adds the element [x] at the end of the queue [q]. *)
  
  val push : 'a -> 'a t -> unit
  (** [push] is a synonym for [add]. *)
  
  val take : 'a t -> 'a
  (** [take q] removes and returns the first element in queue [q],
     or raises {!Empty} if the queue is empty. *)
  
  val take_opt : 'a t -> 'a option
  (** [take_opt q] removes and returns the first element in queue [q],
     or returns [None] if the queue is empty.
     @since 4.08 *)
  
  val pop : 'a t -> 'a
  (** [pop] is a synonym for [take]. *)
  
  val peek : 'a t -> 'a
  (** [peek q] returns the first element in queue [q], without removing
     it from the queue, or raises {!Empty} if the queue is empty. *)
  
  val peek_opt : 'a t -> 'a option
  (** [peek_opt q] returns the first element in queue [q], without removing
     it from the queue, or returns [None] if the queue is empty.
     @since 4.08 *)
  
  val top : 'a t -> 'a
  (** [top] is a synonym for [peek]. *)
  
  val clear : 'a t -> unit
  (** Discard all elements from a queue. *)
  
  val copy : 'a t -> 'a t
  (** Return a copy of the given queue. *)
  
  val is_empty : 'a t -> bool
  (** Return [true] if the given queue is empty, [false] otherwise. *)
  
  val length : 'a t -> int
  (** Return the number of elements in a queue. *)
  
  val iter : ('a -> unit) -> 'a t -> unit
  (** [iter f q] applies [f] in turn to all elements of [q],
     from the least recently entered to the most recently entered.
     The queue itself is unchanged. *)
  
  val fold : ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b
  (** [fold f accu q] is equivalent to [List.fold_left f accu l],
     where [l] is the list of [q]'s elements. The queue remains
     unchanged. *)
  
  val transfer : 'a t -> 'a t -> unit
  (** [transfer q1 q2] adds all of [q1]'s elements at the end of
     the queue [q2], then clears [q1]. It is equivalent to the
     sequence [iter (fun x -> add x q2) q1; clear q1], but runs
     in constant time. *)
  
  (* Ensemble additions.
   *)
  val to_list : 'a t -> 'a list
  val to_array : 'a t -> 'a array
  val clean : ('a -> unit) -> 'a t -> unit
end

module Fqueue : sig
  (**************************************************************)
  (* FQUEUE.MLI : functional queues *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  
  type 'a t
  
  (* Check if empty.
   *)
  val is_empty : 'a t -> bool
      
  (* An empty queue.
   *)
  val empty: 'a t
  
  (* [add x q] adds the element [x] at the end of the queue [q]. 
   *)
  val add: 'a -> 'a t -> 'a t
  
  (* [take q] removes and returns the first element in queue
   * [q], or fails if the queue is empty. 
   *)
  val take: 'a t -> 'a * 'a t
  
  (* [peek q] returns the first element in queue [q], without
   * removing it from the queue, or fails if the
   * queue is empty.  
   *)
  val peek: 'a t -> 'a
  
  (* Return the number of elements in a queue. 
   *)
  val length: 'a t -> int
  
  (* [iter f q] applies [f] in turn to all elements of [q],
   * from the least recently entered to the most recently
   * entered.  The queue itself is unchanged.  
   *)
  val iter: ('a -> unit) -> 'a t -> unit
  
  val map: ('a -> 'b) -> 'a t -> 'b t
  
  (* [fold f i [a;b;c]] is (f a (f b (f c i))).
   *)
  val fold : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
  
  (* Loop is similar to fold except that each time an entry is
   * passed in, the remainder of the queue is also passed in
   * and returned with the new "state".  If the queue is still
   * not empty then the function is called again.  
   *)
  val loop : ('a -> 'b t -> 'b -> 'a * 'b t) -> 'a -> 'b t -> 'a
  
  (* Conversions to/from lists.
   *)
  val to_list : 'a t -> 'a list
  val of_list : 'a list -> 'a t
  
  val of_array : 'a array -> 'a t
end

module Trace : sig
  (**************************************************************)
  (* TRACE.MLI *)
  (* Author: Mark Hayden, 3/96 *)
  (**************************************************************)
  
  val file : string -> string		(* for modules *)
  val filel : string -> string		(* for layers *)
  val file_report : bool -> unit
  
  (**************************************************************)
  
  val log_check : string -> bool
  val log : string -> (unit -> string) -> unit
  val log2 : string -> string -> (unit -> string) -> unit
  val log3 : string -> string -> string -> (unit -> string) -> unit
  val logl : string -> (unit -> string list) -> unit
  val logl2 : string -> string -> (unit -> string list) -> unit
  val logl3 : string -> string -> string -> (unit -> string list) -> unit
  
  val logs_all : unit -> string list
  val logs_all_status : unit -> (string * bool) list
  
  val log_add : string -> (string -> string -> unit) -> unit
  val log_remove : string -> unit
  
  (**************************************************************)
  
  val make_failwith : string -> string -> 'a
  val make_failwith2 : string -> string -> 'a
  
  (**************************************************************)
  
  val dump : (unit -> unit) -> unit
  val debug : 'b -> ('a -> 'b) -> ('a -> 'b)
  val info : string -> string -> string
  
  (**************************************************************)
  
  (* Modules call this in order to register a garbage
   * collection "root".  Calls to print root then call all
   * root callbacks and print out the strings.  This can be
   * helpful in tracking down memory leaks.  
   *)
  val install_root : (unit -> string list) -> unit
  
  val print_roots : unit -> unit
  
  (**************************************************************)
  
  (* Modules can call this in order to register information
   * that might be useful to a user.  Usually, this
   * corresponds to strangenesses in the configuration.  
   *)
  val comment : string -> unit
  
  (**************************************************************)
  
  (* Modules with an embedded test function in them can
   * register it with test_declare.  Other modules can run a
   * test with test_exec.  
   *)
  val test_declare : string -> (unit -> unit) -> unit
  val test_exec : string -> unit
  
  (**************************************************************)
  
  (* Prints out information about the configuration.
   *)
  val config_print : unit -> unit
  
  (**************************************************************)
end

module Arraye : sig
  (**************************************************************)
  (* ARRAYE.MLI : Non-floating point arrays *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  (* These have the same behavior as functions in Array or Util *)
  (**************************************************************)
  
  type 'a t
  
  val append : 'a t -> 'a t -> 'a t
  val blit : 'a t -> int -> 'a t -> int -> int -> unit
  val bool_to_string : bool t -> string
  val combine : 'a t -> 'b t -> ('a * 'b) t
  val concat : 'a t list -> 'a t
  val flatten : 'a t t -> 'a t
  val copy : 'a t -> 'a t
  val create : int -> 'a -> 'a t
  val doubleton : 'a -> 'a -> 'a t
  val empty : 'a t
  val fill : 'a t -> int -> int -> 'a -> unit
  val get : 'a t -> int -> 'a
  val incr : int t -> int -> unit
  val init : int -> (int -> 'a) -> 'a t
  val int_to_string : int t -> string
  val is_empty : 'a t -> bool
  val iter : ('a -> unit) -> 'a t -> unit
  val iteri : (int -> 'a -> unit) -> 'a t -> unit
  val length : 'a t -> int
  val map : ('a -> 'b) -> 'a t -> 'b t
  val mapi : (int -> 'a -> 'b) -> 'a t -> 'b t
  val map2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t
  val mem : 'a -> 'a t -> bool
  val of_array : 'a array -> 'a t
  val of_list : 'a list -> 'a t
  val prependi : 'a -> 'a t -> 'a t
  val set : 'a t -> int -> 'a -> unit
  val singleton : 'a -> 'a t
  val split : ('a * 'b) t -> ('a t * 'b t)
  val sub : 'a t -> int -> int -> 'a t
  val to_array : 'a t -> 'a array
  val to_list : 'a t -> 'a list
  val to_string : ('a -> string) -> 'a t -> string
  val index : 'a -> 'a t -> int
  val filter : ('a -> bool) -> 'a t -> 'a t
  val filter_nones : 'a option t -> 'a t
  val for_all : ('a -> bool) -> 'a t -> bool
  val for_all2 : ('a -> 'b -> bool) -> 'a t -> 'b t -> bool
  val fold : ('a -> 'a -> 'a) -> 'a t -> 'a
  val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
  val fold_right : ('b -> 'a -> 'a) -> 'b t -> 'a -> 'a
  (*val ordered : ('a -> 'a -> bool) -> 'a t -> bool*)
  (*val sort : ('a -> 'a -> bool) -> 'a t -> unit*)
  val ordered : ('a -> 'a -> int) -> 'a t -> bool
  val sort : ('a -> 'a -> int) -> 'a t -> unit
  val exists : (int -> 'a -> bool) -> 'a t -> bool
  
  (**************************************************************)
  (* These functions allows converting an 'a array into a 'b Arraye.t 
   * (and backward) without an intermidiate copy taking place. 
  *)
  
  val of_array_map : ('a -> 'b) -> 'a array -> 'b t
  val to_array_map : ('a -> 'b) -> 'a t -> 'b array
  (**************************************************************)
end

module Arrayf : sig
  (**************************************************************)
  (* ARRAYF.MLI : functional arrays *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  (* These have the same behavior as functions in Array or Util *)
  (**************************************************************)
  
  type 'a t
  
  val append : 'a t -> 'a t -> 'a t
  val bool_to_string : bool t -> string
  val combine : 'a t -> 'b t -> ('a * 'b) t
  val concat : 'a t list -> 'a t
  val copy : 'a t -> 'a t
  val create : int -> 'a -> 'a t
  val doubleton : 'a -> 'a -> 'a t
  val empty : 'a t
  val filter : ('a -> bool) -> 'a t -> 'a t
  val filter_nones : 'a option t -> 'a t
  val flatten : 'a t t -> 'a t
  val for_all : ('a -> bool) -> 'a t -> bool
  val for_all2 : ('a -> 'b -> bool) -> 'a t -> 'b t -> bool
  val fset : 'a t -> int -> 'a -> 'a t
  val get : 'a t -> int -> 'a
  val gossip : bool t -> int -> int t
  val index : 'a -> 'a t -> int
  val init : int -> (int -> 'a) -> 'a t
  val int_to_string : int t -> string
  val max : 'a t -> 'a
  val is_empty : 'a t -> bool
  val iter : ('a -> unit) -> 'a t -> unit
  val iteri : (int -> 'a -> unit) -> 'a t -> unit
  val length : 'a t -> int
  val map : ('a -> 'b) -> 'a t -> 'b t
  val mapi : (int -> 'a -> 'b) -> 'a t -> 'b t
  val map2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t
  val mem : 'a -> 'a t -> bool
  val min_false : bool t -> int
  val of_array : 'a array -> 'a t
  val of_arraye : 'a Arraye.t -> 'a t
  val of_list : 'a list -> 'a t
  val of_ranks : int -> Trans.rank list -> bool t
  val prependi : 'a -> 'a t -> 'a t
  val singleton : 'a -> 'a t
  val split : ('a * 'b) t -> ('a t * 'b t)
  val sub : 'a t -> int -> int -> 'a t
  val super : bool t -> bool t -> bool
  val to_array : 'a t -> 'a array
  val to_arraye : 'a t -> 'a Arraye.t
  val to_list : 'a t -> 'a list
  val to_ranks : bool t -> Trans.rank list
  val to_string : ('a -> string) -> 'a t -> string
  val choose : 'a t -> int -> 'a list
  val fold : ('a -> 'a -> 'a) -> 'a t -> 'a
  val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
  val fold_right : ('b -> 'a -> 'a) -> 'b t -> 'a -> 'a
  (*val ordered : ('a -> 'a -> bool) -> 'a t -> bool*)
  (*val sort : ('a -> 'a -> bool) -> 'a t -> 'a t*)
  val ordered : ('a -> 'a -> int) -> 'a t -> bool
  val sort : ('a -> 'a -> int) -> 'a t -> 'a t
  val exists : (int -> 'a -> bool) -> 'a t -> bool
  
  (**************************************************************)
  (* This should be used with care, it is unsafe. 
   * 
   * It is currently used for a hacky reason in Iovec.ml. 
   * It saves copying an arrayf to an array.
  *)
  val to_array_break : 'a t -> 'a array
  val of_array_break : 'a array -> 'a t
  
  (* These functions allows converting an 'a array into a 'b Arraye.t 
   * (and backward) without an intermidiate copy taking place. 
   * 
   * This is used in ce_util.ml.
  *)
  val of_array_map : ('a -> 'b) -> 'a array -> 'b t
  val to_array_map : ('a -> 'b) -> 'a t -> 'b array
  (**************************************************************)
end

module Buf : sig
  (**************************************************************)
  (* BUF.ML *)
  (* Author: Mark Hayden, 8/98 *)
  (* Rewritten by Ohad Rodeh 9/2001 *)
  (* Buffers are simply immutable strings, where several 
     operations are available on them *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* Type of lengths and offsets.  
   *)
  type len (*= int*) (* should be opaque *)
  type ofs = len
  
  external int_of_len : len -> int = "%identity"
  external len_of_int : int -> len = "%identity"
  external (=||) : len -> len -> bool = "%eq"
  external (<>||) : len -> len -> bool = "%noteq"
  external (>=||) : len -> len -> bool = "%geint"
  external (<=||) : len -> len -> bool = "%leint"
  external (>||) : len -> len -> bool = "%gtint"
  external (<||) : len -> len -> bool = "%ltint"
  external (+||) : len -> len -> len = "%addint"
  external (-||) : len -> len -> len = "%subint"
  external ( *||) : len -> int -> len = "%mulint"
  
  val len0 : len
  val len4 : len
  val len8 : len
  val len12 : len
  val len16 : len
  
  val md5len : len
  val md5len_plus_4 : len
  val md5len_plus_8 : len
  val md5len_plus_12 : len
  val md5len_plus_16 : len
  (**************************************************************)
  
  (* An immutable string
  *)
  type t
  type digest = Digest.t (* A 16-byte immutable string *)
  
  val of_string : string -> t
  val of_bytes : bytes -> t
  val string_of : t -> string
  val bytes_of : t -> bytes
  val blit : t -> ofs -> t -> ofs -> len -> unit
  val blit_str : string -> int -> t -> ofs -> len -> unit
  val check : t -> ofs -> len -> unit
  val concat : t list -> t
  val fragment : len -> t -> t array (* fragment a buffer into parts smaller
  				      than len *)
  val copy : t -> t
  val append : t -> t -> t
  val create : len -> t
  val digest_sub : t -> ofs -> len -> digest
  val digest_substring : string -> int(*ofs*) -> int(*len*) -> digest
  val empty : t
  val int16_of_substring : t -> ofs -> int
  val length : t -> len
  val sub : t -> ofs -> len -> t
  val subeq8 : t -> ofs -> t -> bool
  val subeq16 : t -> ofs -> t -> bool
  val to_hex : string -> string
  
  (* Write integers in standard network format. 
   * This is compatible with the C htonl functions. 
  *)
  val write_int32 : t -> ofs -> int -> unit
  val read_int32  : t -> ofs -> int
  (**************************************************************)
  
  (* Make matched marshallers to/from buffers.
   *)
  val make_marsh : debug -> 
    (('a -> t) * (t -> ofs -> 'a))
  
  (**************************************************************)
  (* The maximum length of messages on the network. 
   *)
  val max_msg_len : len
  (**************************************************************)
  (* We use a preallocated buffer pool, into which objects are
   * marshaled. 
   * 
   * The basic abstraction is a substring (buf,ofs,len). However,
   * currently CAML does not optimize returning tuples from
   * functions, therefore, we pass a continuation function. 
   *
   * The usage is by the routers. An xmit function is passed
   * that sends the substring to the network. 
  *)
  
    
  (* Allocate a substring, and send it. 
  *)
  val prealloc : len -> (t -> ofs -> len -> unit) -> unit
  
  (* Mashal an ML object into a substring and send it. 
  *)  
  val prealloc_marsh : len -> 'a -> (t -> ofs -> len -> unit) -> unit
    
  (**************************************************************)
end

module Iovec : sig
  (**************************************************************)
  (* IOVEC.MLI *)
  (* Author: Mark Hayden, 3/95 *)
  (* Rewritten by Ohad Rodeh 9/2001 *)
  (* This file wraps the Socket.Iovec raw interface in a more 
   * type-safe manner, using offsets and length types. 
   *)
  (**************************************************************)
  (* open Trans *)
  open Buf
  (**************************************************************)
  (* The type of a C memory-buffer. It is opaque.
   *)
  type t = Socket.Iov.t
  type pool = Socket.Iov.pool
      
  (* initialize the memory-manager. 
   * [init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step]
   *)
  val init : bool -> int -> int -> float -> int -> int -> unit
    
  (* Release all the memory used, assuming none is allocated *)
  val shutdown : unit -> unit
    
  (* The pool of sent-messages *)
  val get_send_pool : unit -> pool
    
  (* The pool of recv-messages *)
  val get_recv_pool : unit -> pool
    
  (* allocation, and copy. 
  *)
  val buf_of : t -> Buf.t
  val buf_of_full : Buf.t -> len -> t -> unit
  val of_buf : pool -> Buf.t -> ofs -> len -> t
  
  val empty : t
  
  (* Length of an iovec
  *)  
  val len : t -> len
  
  val alloc_async : pool -> len -> (t -> unit) -> unit
  
  (* May throw an Out_of_iovec_memory exception, if the
   * user has no more free memory to hand out.
   *)
  val alloc : pool -> len -> t
    
  val sub : t -> ofs -> len -> t
    
  (* Decrement the refount, and free the cbuf if the count
   * reaches zero. 
   *)
  val free : t -> unit 
    
  (* Increment the refount, do not really copy. 
   *)
  val copy : t -> t 
  
  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   *
   * Throws an Out_of_iovec_memory exception, if 
   * user memory has run out.
   *)
  val flatten : t array -> t
  
  (**************************************************************)  
  (* For debugging. Return the number of references to the iovec.
  *)
  val num_refs : t -> int
  
  (* Return the number of iovecs currrently held, and the total length.
   *)
  val debug : unit -> int * int
  
  (* Marshal directly into an iovec.
   *
   * Unmarshal directly from an iovec. Raises an exception if there
   * is a problem, and checks for out-of-bounds problems. 
   *)
  val marshal : pool -> 'a -> Marshal.extern_flags list -> t
  val unmarshal : t-> 'a
  
  (**************************************************************)
  val get_stats : unit -> string
  (**************************************************************)
    
    
end

module Iovecl : sig
  (**************************************************************)
  (* IOVECL.MLI: operations on arrays of Iovec's. *)
  (* Author: Mark Hayden, 3/95 *)
  (* Completely rewritten by Ohad Rodeh 9/2001 *)
  (**************************************************************)
  (* open Trans *)
  open Buf
  (**************************************************************)
  (* Type of Iovec arrays.
   *)
  type t 
  
  val to_arrayf : t -> Iovec.t Arrayf.t
  val of_iovec_arrayf : Iovec.t Arrayf.t -> t
  val of_iovec_array : Iovec.t array -> t
  val to_iovec_array : t -> Iovec.t array
  (**************************************************************)
  
  (* refcount operation to all member iovecs.  See Iovec.mli
   *)
  val free : t -> unit
  val copy : t -> t
  val get : t -> int -> Iovec.t
  val array_len : t -> int
  
  (**************************************************************)
  
  (* Calculate total length of an array of iovecs.
   *)
  val len : t -> len
  
  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   * The reference count is incremented if this is a singleton
   * array.
   *)
  val flatten : t -> Iovec.t
  
  (* Catenate an array of iovec arrays. Used in conjunction with 
   * flatten.
   *)
  val concata : t Arrayf.t -> t
  
  
  (* Make a marshaller for arrays of iovecs.  
   * 
   * PERF: there is an extra copy here that should be 
   * eliminated. This effects ML applications.
   * 
   * The boolean flags describes whether to free the iovecl's
   * after unmarshaling it into an ML value.
   *)
  val make_marsh : Iovec.pool -> bool -> (('a -> t) * (t -> 'a))
  
  (* An empty iovec array.
   *)
  val empty : t
  val is_empty : t -> bool
  
  (* Wrap a normal iovec.  Takes the reference count.
   *)
  val of_iovec : Iovec.t -> t
  
  (* Append two iovec arrays.
   *)
  val append : t -> t -> t
  
  (* Prepend a single iovec to an iovec array.
   *)
  val prependi : Iovec.t -> t -> t
  val appendi : t -> Iovec.t -> t
  
  (* This is used for reading Iovecls from left to right.
   * The loc objects prevent the sub operation from O(n^2)
   * behavior when repeatedly sub'ing an Iovecl.  loc0 is
   * then beginning of the iovecl.
   * 
   * The reference counts of all iovec's that are in the 
   * sub-vector are incremented. 
   *)
  type loc = int * ofs (* position [ofs] in the i-th iovec *)
  val loc0 : loc
  val sub_scan : loc -> t -> ofs -> len -> t * loc
  
  val sub : t -> ofs -> len -> t 
  
  (* Fragment iovec array into an array of iovec arrays of
   * some maximum size.  No copying occurs.  The resulting
   * iovec arrays are at most the specified length.
   *)
  val fragment : len -> t -> t Arrayf.t
  
  (* Check if iovecl has only one Iovec.  If it does,
   * Get_singleton will extract it. 
   * get_singleton fails if there is more than one
   * iovec.  
   *)
  val singleton : Iovec.t -> t
  val is_singleton : t -> bool
  val get_singleton : t -> Iovec.t
  val count_nonempty : t -> int
  
  (**************************************************************)
  (* Summerize the number of references to each part of the iovec.
  *)
  val sum_refs : t -> string
  (**************************************************************)
    
end

module Marsh : sig
  (**************************************************************)
  (* MARSH.MLI *)
  (* Author: Mark Hayden, 12/96 *)
  (* Modified by Ohad Rodeh, 10/2001 *)
  (**************************************************************)
  (* This now provides by hand marshaling for strings and integers.
   * The usage is for C applications that need to communicate
   * through an agreed protocol with ML. *)
  (**************************************************************)
  (* open Trans *)
  (* open Buf *)
  (**************************************************************)
  
  (* Type of marshalled objects: used at sender.
   *)
  type marsh
  
  (* Initialize a marshaller.
   *)
  val marsh_init : unit -> marsh
  
  (* Convert a marshaller into a buffer.
   *)
  val marsh_done : marsh -> Buf.t
  
  (* Functions for adding data to a string.
   *)
  val write_int    : marsh -> int -> unit
  val write_bool   : marsh -> bool -> unit
  val write_string : marsh -> string -> unit
  val write_buf    : marsh -> Buf.t -> unit
  val write_list   : marsh -> ('a -> unit) -> 'a list -> unit
  val write_array  : marsh -> ('a -> unit) -> 'a array -> unit
  val write_option : marsh -> ('a -> unit) -> 'a option -> unit
  
  (**************************************************************)
  
  (* Type of unmarshalling objects: used at receiver.
   *)
  type unmarsh
  
  (* This exception is raised if there is a problem
   * unmarshalling the message.  
   *)
  exception Error of string
  
  (* Convert a buffer into an unmarsh object.
   *)
  val unmarsh_init : Buf.t -> Buf.ofs -> Buf.len -> unmarsh
  
  val unmarsh_check_done_all : unmarsh -> unit (* we should have read it all *)
  
  (* Functions for reading from marshalled objects.
   *)
  val read_int    : unmarsh -> int
  val read_bool   : unmarsh -> bool
  val read_string : unmarsh -> string
  val read_buf    : unmarsh -> Buf.t
  val read_list   : unmarsh -> (unit -> 'a) -> 'a list
  val read_option : unmarsh -> (unit -> 'a) -> 'a option
  
  (**************************************************************)
end

module Security : sig
  (**************************************************************)
  (* SECURITY *)
  (* Authors: Mark Hayden, 6/95 *)
  (* Refinements: Ohad Rodeh 10/98 7/2000 *)
  (**************************************************************)
  (* open Trans
  open Buf *)
  (**************************************************************)
  
  (* Type of keys in Ensemble.
   * A key has two parts: 
   * 1. mac-key, used for keyed-hashing. 
   * 2. encyrption key, used for encryption functions.
   * Each of the subkeys are 16 bytes long. 
   *)
  type mac 
  type cipher 
  
  type inner_key = {
    mac     : mac ;
    cipher  : cipher 
  }
      
  type key = 
    | NoKey
    | Common of inner_key
  
  val mac_len  : Buf.len
  val cipher_len : Buf.len
  val key_len : Buf.len  (* The standard length of keys. They are currently 32 bytes long *)
  
  
  val buf_of_cipher : cipher -> Buf.t
  val cipher_of_buf : Buf.t -> cipher 
  val buf_of_mac :  mac -> Buf.t
  val mac_of_buf :  Buf.t -> mac
  
  (* Accessor functions
  *)
  val get_mac : key -> mac
  val get_cipher : key -> cipher
  
  (* Get the Buf.t contents of a key.
   *)
  val buf_of_key : key -> Buf.t
  
  (* Get a textual representation of the key for printing out
   * to the user.  
   *)
  val string_of_key_short : key -> string
  val string_of_key : key -> string
  
  (* Convert a 32byte buf into a key. 
  *)
  val key_of_buf : Buf.t -> key
end

module Tree : sig
  (**************************************************************)
  (* TREE.MLI : D-WGL algorithm *)
  (* Author: Ohad Rodeh, 2/99 *)
  (**************************************************************)
  
  module type OrderedKey = sig
    type t
  
    val compare : t -> t -> int
    val rand    : unit -> t 
    val string_of_t : t -> string
  end
  
  module type OrderedMember = sig
    type t 
  
    val of_int  : int -> t
    val int_of  : t -> int
    val compare : t -> t -> int
    val string_of_t : t -> string
  end
  
  (*********************************************************************)
  module type S = sig
    type t 
    type member
    type key 
  
      (* A list of actions describing the merging of several trees.
       *)
    type alist  
  
    (* The set of actions to be performed by a member. 
     *)
    type memrec = {
      mutable send : (member * key) list ;
      mutable cast1: (key list * key) list ;
      mutable recv : key option ;
      mutable cast2: (key * key) option
    }
  
    val string_of_memrec : memrec -> string
  
    (* A mapping between member and its original tree.
     *)
    type memmap 
  
    type keytable = (key, t) Hashtbl.t
    type actions_h = (member, memrec) Hashtbl.t
  
    (* The full information about a merge of several trees
     *)
    type full = actions_h * memmap * keytable * (key * key) list
    type sent = actions_h * (key * key) list
  
    type debug_map 
      
    (* merge a list of trees.
     *)
    val merge  : t list -> t * alist  
  
    (* Replace the top key with a new one.
     *)
    val new_top : t -> t * alist
  
    val string_of_t : t -> string
    val height_string_of_t : t -> string
    val string_of_alist : alist -> string
    val actions_of_merge : t -> alist -> full
    val string_of_full : full -> string
    val string_of_keytable : keytable  -> string
    val string_of_debug_map : debug_map -> string 
  
    (* [decrypt keyl mcl] Compute the set of keys decryptable from the list [mcl] 
     * assuming [keyl] are known 
    *)
    val decrypt : key list -> (key list * key) list -> key list
      
    (* Compute the total set of multicasts performed 
     *)
    val mcast_sweep : actions_h -> (key list * key) list 
  
    (* [self_check verbose tree full] checks whether the (tree,full) 
     * are correct. All members may encrypt only with keys they know, and 
     * all members must receive all the keys they need. 
     *)
    val self_check : bool -> t -> full -> debug_map * bool * string 
        
    (* Zipping and unzipping trees. Trees have to be passed through
     * the network, in order to reduce message size their size should
     * be reduced. 
     *)
    type z 
    val string_of_z : z -> string
    val zip : t -> z 
    val unzip : z -> t 
    val zempty : z
    val zleaf  : member -> z
    val zam_leader : z -> member -> bool 
    val members_of_z : z -> member list
  
    (* [keylist full member] find the list of keys from [member] to the root on 
     * tree [t] 
     *)
    val zkeylist : z -> member -> key list
  
    (* [remove_members_spec tree member rmv_l] returns the largest subtree 
     * of [tree] that contains [member] but does not contain any member from
     * [rmv_l].
     *)
    val zremove_members_spec : z -> member -> member list -> z
  
    (* [zmap f g tree] Map the tree. [f] works on the members, [g]
     * works on the keys. 
     *)
    val zmap   : (member -> member) -> (key -> key) -> z -> z
  end
  
  module Make(Member: OrderedMember) (Key: OrderedKey) : (S with type member = Member.t and type key=Key.t)
  (*********************************************************************)
  
  
end

module Mrekey_dt : sig
  (**************************************************************)
  (* MREKEY_DT.MLI : Dynamic Tree rekey support module *)
  (* Author: Ohad Rodeh, 4/2000 *)
  (*************************************************************************)
  open Trans
  
  type t 
  
  (* An empty tree. Used so that we would not have to reveal the 
   * inner structure of type t.
  *)
  val empty : t
  
  val string_of_t : t -> string
  val singleton :   rank -> t
  val children : t -> rank -> rank list
  val father   : t -> rank -> rank option
  val members_of_t : t -> rank list
  val map   : (rank -> rank) -> t -> t
  
  val split : t -> rank -> rank list -> t
  val merge : t list -> t
  
  val pretty_string_of_t : t -> string
  
  
  (*************************************************************************)
end

module Hsys : sig
  (**************************************************************)
  (* HSYS.MLI *)
  (* Author: Mark Hayden, 5/95 *)
  (**************************************************************)
  open Buf
  (**************************************************************)
  val max_msg_size : int
  
  type debug = string
  type port = int
  type inet = Unix.inet_addr
  type socket = Socket.socket 
  type mcast_send_recv = Socket.mcast_send_recv = 
    | Recv_only
    | Send_only
    | Both
  
  
  type timeval = {
    mutable sec10 : int ;
    mutable usec : int
  } 
  
  (**************************************************************)
  (* The following are essentially the same as the functions of
   * the same name in the Unix library.
   *)
  val accept : socket -> socket * inet * port
  val bind : socket -> inet -> port -> unit
  val close : socket -> unit
  val connect : socket -> inet -> port -> unit
  val gethost : unit -> inet
  val getlocalhost : unit -> inet
  val gethostname : unit -> string
  val getlogin : unit -> string
  val getpeername : socket -> inet * port
  val getsockname : socket -> inet * port
  val gettimeofday : unit -> timeval
  val inet_any : unit -> inet
  val inet_of_string : string -> inet
  val listen : socket -> int -> unit
  val read : socket -> bytes -> int (*ofs*) -> int (*len*) -> int
  val recvfrom : socket -> Buf.t -> Buf.ofs -> Buf.len -> Buf.len * inet * port
  val string_of_inet : inet -> string	(* i.e. gethostbyname *)
  val string_of_inet_nums : inet -> string
  val getenv : string -> string option
  val getpid : unit -> int
  
  (**************************************************************)
  
  (* Bind to any port.  Returns port number used.
   *)
  val bind_any : debug -> socket -> inet -> port
  
  (**************************************************************)
  
  (* This only returns the host name and none of the
   * domain names (everything up to the first '.'.
   *)
  val string_of_inet_short : inet -> string
  
  (**************************************************************)
  
  (* Create a random deering address given an integer 'seed'.
   *)
  val deering_addr : int -> inet
  
  (**************************************************************)
  
  (* Same as Unix.gettimeofday, except that a timeval record
   * is passed in and the return value is written there.  See
   * ensemble/socket/socket.mli for an explanation.  
   *)
  val gettimeofdaya : timeval -> unit
  
  (**************************************************************)
  
  (* Was Ensemble compiled with ip multicast and does this host
   * support it.
   *)
  val has_ip_multicast : unit -> bool
  
  (**************************************************************)
  
  (* Integer value of a socket.  For debugging only.  On Unix,
   * this gives the file descriptor number.  On Windows, this
   * gives the handle number, which is somewhat different from
   * Unix file descriptors.  
   *)
  val int_of_socket : socket -> int
  
  (**************************************************************)
  
  (* A variation on fork().  [open_process command input]
   * creates a process of the given name and writes [input] to
   * its standard input.  Returns a tuple, where the first
   * entry specifies if the process exited successful.  The
   * second value is the standard output, and the third value
   * is the standard error.  
   *)
  
  val open_process : string -> string array -> string -> (bool * string * string)
  
  val background_process : string -> string array -> string -> 
    (in_channel * out_channel * in_channel) * socket * socket
  
  
  (**************************************************************)
  
  (* Handlers that are used for the pollinfo/polling
   * functions.  The first kind of handler specifies a
   * callback to make when there is data ready to read on the
   * socket.  The second kind of handler specifies that the
   * polling function is to recv() data from the socket into
   * its own buffer and pass the data up a central handler
   * (specified in the call to the pollinfo() function).  
   *)
  type handler =
    | Handler0 of (unit -> unit)
    | Handler1
  
  (**************************************************************)
  
  (* This is an optimized version of the select function.  You
   * passing in select_info arguments for the read, write, and
   * exception conditions, as with normal select.  However,
   * this function specifies which sockets have data by
   * modifying the boolean values in the array that are
   * associated with the appropriate socket.  
   *)
  
  (* Note: both arrays here should be of the same length.
   *)
  type sock_info = ((socket array) * (bool array)) option
  type select_info
  
  val select_info : sock_info -> sock_info -> sock_info -> select_info
  
  val select : select_info -> timeval -> int
  
  (* This is the same as select, except that the timeout is
   * always 0.0.  
   *)
  val poll : select_info -> int
  
  (**************************************************************)
  
  (* Optimized sending functions.  You first call sendto_info
   * with the socket to send on, and an array of destinations.
   * This returns a preprocessed data structure that can be
   * used later to actually do the sends with.  The sendto and
   * sendtov functions do not check for errors.
   *)
  type sendto_info
  
  val tcp_info : socket -> sendto_info
  val sendto_info : socket -> (inet * port) array -> sendto_info
  
  val udp_send : sendto_info -> Buf.t -> ofs -> len -> unit
  val udp_mu_sendsv : sendto_info -> Buf.t -> ofs -> len -> Iovecl.t -> unit
  val udp_mu_recv_packet : Iovec.pool -> socket -> Buf.t -> len(*int*) * Iovec.t
  
  (* In the TCP functions, exceptions are caught, logged, and len0 
   * is returned instead.
  *)
  val tcp_send : socket -> Buf.t -> ofs -> len -> len
  val tcp_sendv : socket -> Iovecl.t -> len
  val tcp_sendsv : socket -> Buf.t -> ofs -> len -> Iovecl.t -> len
  val tcp_sends2v : socket -> Buf.t -> Buf.t -> ofs -> len -> Iovecl.t -> len
  val tcp_recv : socket -> Buf.t -> ofs -> len -> len
  val tcp_recv_iov : socket -> Iovec.t -> ofs -> len -> len
  val tcp_recv_packet : socket -> Buf.t -> ofs -> len -> Iovec.t -> len
  
  (**************************************************************)
  
  (* Options passed to setsockopt.
   *)
  type socket_option =
    | Nonblock of bool
    | Reuse
    | Join of inet * mcast_send_recv
    | Leave of inet
    | Ttl of int 
    | Loopback of bool
    | Sendbuf of int
    | Recvbuf of int
    | Bsdcompat of bool
  
  (* Set one of the above options on a socket.
   *)
  val setsockopt : socket -> socket_option -> unit
  
  (* Is this a class D address ?
  *)
  val in_multicast : Unix.inet_addr -> bool
  (**************************************************************)
  
  (* Create a datagram (UDP) or a stream (TCP) socket.
   *)
  val socket_dgram : unit -> socket
  val socket_stream : unit -> socket
  val socket_mcast : unit -> socket
  
  (**************************************************************)
  
  (* Check if portions of two strings are equal.
   *)
  val substring_eq : Buf.t -> ofs -> Buf.t -> ofs -> len -> bool
  
  (**************************************************************)
  
  (* MD5 support.
   *
  type md5_ctx
  val md5_init : unit -> md5_ctx
  val md5_init_full : string -> md5_ctx
  val md5_update : md5_ctx -> Buf.t -> ofs -> len -> unit
  val md5_final : md5_ctx -> Digest.t
  
  val md5_update_iovl : md5_ctx -> Iovecl.t -> unit *)
  (**************************************************************)
  
  (* Create a socket connected to the standard input.
   * See ensemble/socket/stdin.c for an explanation of
   * why this is necessary.
   *)
  val stdin : unit -> socket
  
  (**************************************************************)
  
  (*val heap : unit -> Obj.t array
  val addr_of_obj : Obj.t -> string*)
  val minor_words : unit -> int
  (*val frames : unit -> int array array*)
  
  (**************************************************************)
  
  (* These simply returns the text readable value the
   * inet (XXX.YYY.ZZZ.TTT). Used for safe marshaling routines.
  *)
  val simple_string_of_inet  : inet -> string 
  val simple_inet_of_string  : string -> inet 
  
  (**************************************************************)
  
  (* Do whatever is necessary to create and initialize a UDP
   * socket.
   * 
   * The [int] argument is the size of the socket buffers to
   * ask the kernel to reserve. This can be gotten by using
   * Arge.get Arge.sock_buf. 
   * 
   * This can't be done here, because Hsys is below Arge.
   *)
  val udp_socket : int  -> socket
  val multicast_socket : int -> socket
  (**************************************************************)
  
end

module Lset : sig
  (**************************************************************)
  (* LSET.MLI *)
  (* Author: Mark Hayden, 11/96 *)
  (**************************************************************)
  (* Efficient set-like operations for lists.
  
   * All functions that return lists, return ordered lists.
  
   * Set operations take linear time when input lists are in order.
  
   *) 
  (**************************************************************)
  
  (* [sort l] returns the list [l] where all items are
   * sorted.  If the list is already sorted, the same list is
   * returned. 
   *)
  val sort : 'a list -> 'a list
  
  (* [subtract l1 l2] returns the list [l1] where all elements
   * structurally equal to one of the elements of [l2] have
   * been removed. 
   *)
  val subtract : 'a list -> 'a list -> 'a list
  
  (* [union l1 l2] returns list with all of the items in [l1]
   * and [l2].  Duplicates are stripped. 
   *)
  val union : 'a list -> 'a list -> 'a list
  
  (* [intersect l1 l2] returns list of elements in both [l1] and
   * [l2].  
   *)
  val intersect : 'a list -> 'a list -> 'a list
  
  (* [super l1 l2] determines whether the items in [l1] are a
   * superset of those in [l2] (they may be equal). 
   *)
  val super : 'a list -> 'a list -> bool
  
  (* [disjoin l1 l2] determines whether [l1] and [l2] are
   * disjoint.  
   *)
  val disjoint : 'a list -> 'a list -> bool
  
  val collapse : 'a list -> 'a list
  
  (**************************************************************)
  type 'a t
  val inject : 'a Arrayf.t -> 'a t
  val project : 'a t -> 'a Arrayf.t
  
  val sorta : 'a t -> 'a t
  val subtracta : 'a t -> 'a t -> 'a t
  val uniona : 'a t -> 'a t -> 'a t
  val intersecta : 'a t -> 'a t -> 'a t
  val supera : 'a t -> 'a t -> bool
  val disjointa : 'a t -> 'a t -> bool
  
  val is_empty : 'a t -> bool
  val to_string : ('a -> string) -> 'a t -> string
  (**************************************************************)
end

module Resource : sig
  (**************************************************************)
  (* RESOURCE.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type ('a,'b) t
  
  val create : 
    name -> 
    ('a -> 'b -> unit) ->			(* add *)
    ('a -> 'b -> unit) ->			(* remove *)
    (('a,'b) t -> unit) ->		(* change *)
    (('a,'b) t -> unit) ->		(* minimal change *)
    ('a,'b) t
  
  val simple 	: name -> ('a,'b) t
  val add       	: ('a,'b) t -> debug -> 'a -> 'b -> unit
  val remove 	: ('a,'b) t -> 'a -> unit
  
  val to_array	: ('a,'b) t -> 'b Arrayf.t
  
  val info	: ('a,'b) t -> string
  val to_string   : ('a,'b) t -> string
end

module Sched : sig
  (**************************************************************)
  (* SCHED.MLI: call-back scheduling *)
  (* Author: Mark Hayden, 12/95 *)
  (**************************************************************)
  open Trans
  
  type t
  
  (* Create a scheduling queue.
   *)
  val create : debug -> t
  
  (* Enqueue a function and its arguments.
   *)
  val enqueue : t -> debug -> (unit -> unit) -> unit
  val enqueue_1arg : t -> debug -> ('a -> unit) ->  'a -> unit
  val enqueue_2arg : t -> debug -> ('a -> 'b -> unit) -> 'a -> 'b -> unit
  val enqueue_3arg : t -> debug -> ('a -> 'b -> 'c -> unit) -> 'a -> 'b -> 'c -> unit
  val enqueue_4arg : t -> debug -> ('a -> 'b -> 'c -> 'd -> unit) -> 'a -> 'b -> 'c -> 'd -> unit
  val enqueue_5arg : t -> debug -> ('a -> 'b -> 'c -> 'd -> 'e -> unit) -> 'a -> 'b -> 'c -> 'd -> 'e -> unit
  
  (* Is it empty?
   *)
  val empty : t -> bool
  
  (* What's its size?
   *)
  val size : t -> int
  
  (* Execute this number of steps.  Returns true if
   * some steps were made.  The #steps is assumed to
   * be > 0.
   *)
  val step : t -> int -> bool
  
  (**************************************************************)
  
  (* Global variable: #of scheduling steps taken so far.
   *)
  val steps : int ref
  
  (**************************************************************)
end

module Time : sig
  (**************************************************************)
  (* TIME.MLI *)
  (* Author: Mark Hayden, 8/96 *)
  (**************************************************************)
  
  type t
  
  val invalid 	: t
  val zero 	: t
  val neg_one     : t
  
  val of_int	: int -> t		(* secs *)
  val of_ints     : int -> int -> t	(* secs -> usecs *)
  val of_string   : string -> t
  val of_float 	: float -> t
  
  val to_float 	: t -> float
  val to_string 	: t -> string
  val to_string_full : t -> string
  val to_timeval  : t -> Hsys.timeval
  val of_timeval  : Hsys.timeval -> t
  
  val add 	: t -> t -> t
  val sub 	: t -> t -> t
  
  val gettimeofday : unit -> t
  val select      : Hsys.select_info -> t -> int
  
  val is_zero     : t -> bool
  val is_invalid  : t -> bool
  val ge          : t -> t -> bool
  val gt          : t -> t -> bool
  val cmp         : t -> t -> int
  
  module Ord : (Trans.OrderedType with type t = t)
  
  (**************************************************************)
  (* Another version of the above stuff with in-place 
   * modification.  Use at your own risk.
   *)
  
  (* I wanted to export this stuff in a separate module
   * but the compiler wasn't inlining the calls.
   *)
  type m
  val mut         : unit -> m
  val mut_set     : m -> t -> unit
  val mut_copy    : m -> t
  val mut_ge      : m -> t -> bool
  val mut_add     : m -> t -> unit
  val mut_sub     : m -> t -> unit
  val mut_sub_rev : t -> m -> unit
  val mut_gettimeofday : m -> unit
  val mut_select  : Hsys.select_info -> m -> int
  
  (*
  type m' = m
  module Mut_hide : sig
    type m = m'
    val zero    : unit -> m
    val of_int  : m -> int -> unit
    val copy    : m -> t
    val ge      : m -> t -> bool
    val add     : m -> t -> unit
    val sub     : m -> t -> unit
    val sub_rev : t -> m -> unit
    val gettimeofday : m -> unit
    val select  : Hsys.select_info -> m -> int
  end
  *)
  (**************************************************************)
end

module Addr : sig
  (**************************************************************)
  (* ADDR.MLI *)
  (* Author: Mark Hayden, 12/95 *)
  (**************************************************************)
  open Trans
  
  (* Address ids.
   *)
  type id =
    | Deering
    | Netsim
    | Tcp
    | Udp
    | Pgp
  
  (* Addresses.
   *)
  type t =
    | DeeringA of Hsys.inet * port
    | NetsimA
    | TcpA of Hsys.inet * port
    | UdpA of Hsys.inet * port
    | PgpA of string
  
  (* Processes actually use collections of addresses.
   *)
  type set
  
  (* Display functions.
   *)
  val string_of_id : id -> string
  val string_of_id_short : id -> string	(* just first char *)
  val string_of_addr : t -> string
  val string_of_set : set -> string
  
  (* Conversion functions.
   *)
  val set_of_arrayf : t Arrayf.t -> set
  val arrayf_of_set : set -> t Arrayf.t
  val id_of_addr : t -> id
  val id_of_string : string -> id
  val ids_of_set : set -> id Arrayf.t
  val project : set -> id -> t
  
  (* Info about ids.
   *)
  val has_mcast : id -> bool
  val has_pt2pt : id -> bool
  val has_auth : id -> bool
  
  (* Sets of addresses are on the same process if any of the 
   * addresses are the same.  (Is this correct?)
   *)
  val same_process : set -> set -> bool
  
  (* Remove duplicated destinations.  [compress my_addr
   * addresses] returns tuple with whether any elements of the
   * view were on the same process and a list of addresses with
   * distinct processes.  
   *)
  val compress : set -> set Arrayf.t -> bool * set Arrayf.t
  
  (* Default ranking of modes.  Higher is better.
   *)
  val default_ranking : id -> int
  
  (* Choose "best" mode to use.
   *)
  val prefer : (id -> int) -> id Arrayf.t -> id
  
  (* Explain problem with these modes.
   *)
  val error : id Arrayf.t -> unit
  
  val modes_of_view : set Arrayf.t -> id Arrayf.t
  
  (**************************************************************)
  (* Support for safe marshaling
   *)
  val safe_string_of_set : set -> string
  val safe_set_of_string : string -> set 
  (**************************************************************)
        
end

module Proto : sig
  (**************************************************************)
  (* PROTO.MLI *)
  (* Author: Mark Hayden, 11/96 *)
  (* see also appl/property.mli *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type id					(* stack *)
  type l					(* layer *)
  
  (**************************************************************)
  
  val string_of_id : id -> string
  val id_of_string : string -> id
  
  (**************************************************************)
  
  val layers_of_id : id -> l list
  val string_of_l : l -> name
  val l_of_string : name -> l
  
  (**************************************************************)
end

module Stack_id : sig
  (**************************************************************)
  (* STACK_ID.MLI *)
  (* Author: Mark Hayden, 3/96 *)
  (**************************************************************)
  
  type t =
    | Primary
    | Bypass
    | Gossip
    | Unreliable
  
  val string_of_id : t -> string
  
  val id_of_string : string -> t
end

module Unique : sig
  (**************************************************************)
  (* UNIQUE.MLI *)
  (* Author: Mark Hayden, 8/96 *)
  (**************************************************************)
  open Trans
  
  (* Id generator.
   *)
  type t
  
  (* Unique identifiers.
   *)
  type id
  
  (* Constructors.
   *)
  val create : Hsys.inet -> incarn -> t
  val id : t -> id
  
  (* Display functions.
   *)
  val string_of_id : id -> string
  val string_of_id_short : id -> string
  val string_of_id_very_short : id -> string
  
  (* Hash an id.
   *)
  val hash_of_id : id -> int
  
  (**************************************************************)
  val set_port : t -> port -> unit
  (**************************************************************)
end

module Endpt : sig
  (**************************************************************)
  (* ENDPT.MLI *)
  (* Author: Mark Hayden, 7/95 *)
  (**************************************************************)
  (* open Trans *)
  (**************************************************************)
  
  (* Type of endpoints.
   *)
  type id
  
  type full = id * Addr.set
  
  (* Constructors.  The named endpoints are only used for
   * debugging purposes.  Named endpoints (as opposed to named
   * groups which just have a string) still contain a unique
   * identifier along with the name.  
   *)
  val id		        : Unique.t -> id (* anonymous endpoints *)
  val named               : Unique.t -> string -> id (* named endpoints *)
  
  (* Yet another way to create an endpoint.  In this case, the
   * string given must provide the uniqueness of the endpoint.
   * In other words, the string passed here must be
   * system-wide unique.  Also, the string_of_id function
   * returns the string value used here.  This function is used
   * in implementing external interfaces where it may be useful
   * to be able to generate the endpoint information elsewhere
   * instead of requesting it from this module.  Because of this,
   * the string input here should usually not contain spaces or
   * non-printable characters.
   *)
  val extern              : string -> id
  
  (* Display functions.
   *)
  val string_of_id	: id -> string
  val string_of_id_short	: id -> string
  val string_of_id_very_short : id -> string
  val string_of_full      : full -> string
  
  val string_of_id_list	: id list -> string
  
  (**************************************************************)
end

module Group : sig
  (**************************************************************)
  (* GROUP.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  
  (* Type of group identifiers.
   *)
  type id
  
  (* Constructors.
   *)
  val id    : Unique.id -> id		(* anonymous groups *)
  val named : string -> id		(* named groups *)
  
  (* Display function.
   *)
  val string_of_id : id -> string
  
  (* Hash an id (used for selecting IP multicast address).
   *)
  val hash_of_id : id -> int
  
  (**************************************************************)
end

module Param : sig
  (**************************************************************)
  (* PARAM.MLI *)
  (* Author: Mark Hayden, 12/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* The type of parameters.
   *)
  type t =
    | String of string
    | Int of int
    | Bool of bool
    | Time of Time.t
    | Float of float
  
  (* Parameter lists are (name,value) association lists.
   *)
  type tl = (name * t) list
  
  (* Add a parameter to the defaults.
   *)
  val default : name -> t -> unit
  
  (* Lookup a parameter in a param list.
   *)
  val lookup : tl -> name -> t
  
  (* Lookup a particular type of parameter.
   *)
  val string : tl -> name -> string
  val int : tl -> name -> int
  val bool : tl -> name -> bool
  val time : tl -> name -> Time.t
  val float : tl -> name -> float
  
  val to_string : (name * t) -> string
  
  (* Print out default settings.
   *)
  val print_defaults : unit -> unit
end

module Version : sig
  (**************************************************************)
  (* VERSION.ML *)
  (* Author: Mark Hayden, 6/96 *)
  (**************************************************************)
  
  type id
  
  val id : id
  
  val string_of_id : id -> string
end

module View : sig
  (**************************************************************)
  (* VIEW.MLI *)
  (* Author: Mark Hayden, 3/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* VIEW.T: an array of endpt id's.  These arrays should
   * be treated as though they were immutable.
   *)
  type t = Endpt.id Arrayf.t
  
  val to_string : t -> string
  
  (**************************************************************)
  
  (* VIEW.ID: a logical time and an endpoint id.  View
   * identifiers have a lexicographical total ordering.  
   *)
  type id = ltime * Endpt.id
  
  (* Display function for view id's.
   *)
  val string_of_id : id -> string
  
  (**************************************************************)
  
  (* VIEW.STATE: a record of information kept about views.
   * This value should be common to all members in a view.
   *)
  type state = {
    (* Group information.
     *)
    version       : Version.id ;		(* version of Ensemble *)
    group		: Group.id ;		(* name of group *)
    proto_id	: Proto.id ;		(* id of protocol in use *)
    coord         : rank ;		(* initial coordinator *)
    ltime         : ltime ;		(* logical time of this view *)
    primary       : primary ;		(* primary partition? (only w/some protocols) *)
    groupd        : bool ;		(* using groupd server? *)
    xfer_view	: bool ;		(* is this an XFER view? *)
    key		: Security.key ;	(* keys in use *)
    prev_ids      : id list ;             (* identifiers for prev. views *)
    params        : Param.tl ;		(* parameters of protocols *)
    uptime        : Time.t ;		(* time this group started *)
  
    (* Per-member arrays.
     *)
    view 		: t ;			(* members in the view *)
    clients	: bool Arrayf.t ;	(* who are the clients in the group? *)
    address       : Addr.set Arrayf.t ;	(* addresses of members *)
    out_of_date   : ltime Arrayf.t	; (* who is out of date *)
    lwe           : Endpt.id Arrayf.t Arrayf.t ; (* for light-weight endpoints *)
    protos        : bool Arrayf.t  	(* who is using protos server? *)
  }
  
  (* FIELDS: these correspond to the fields of a View.state.
   *)
  type fields =
    | Vs_coord        of rank
    | Vs_group	    of Group.id
    | Vs_view 	    of t
    | Vs_ltime        of ltime
    | Vs_params	    of Param.tl
    | Vs_prev_ids     of id list
    | Vs_proto_id	    of Proto.id
    | Vs_xfer_view    of bool
    | Vs_key	    of Security.key
    | Vs_clients	    of bool Arrayf.t
    | Vs_groupd       of bool
    | Vs_protos       of bool Arrayf.t
    | Vs_primary      of primary
    | Vs_address      of Addr.set Arrayf.t
    | Vs_out_of_date  of ltime Arrayf.t
    | Vs_lwe          of Endpt.id Arrayf.t Arrayf.t
    | Vs_uptime       of Time.t
  
  
  (* SET: Construct new view state based on previous view state.
   *)
  val set : state -> fields list -> state
  
  val string_of_state : state -> string
  
  val id_of_state : state -> id
  
  (**************************************************************)
  
  (* VIEW.LOCAL: information about a view that is particular to 
   * a member.
   *)
  type local = {
    endpt	        : Endpt.id ;		(* endpoint id *)
    addr	        : Addr.set ;		(* my address *)
    rank 	        : rank ;		(* rank in the view *)  
    name		: string ;		(* my string name *)
    nmembers 	: nmembers ;		(* # members in view *)
    view_id 	: id ;			(* unique id of this view *)
    am_coord      : bool ;  		(* rank = vs.coord? *)
    falses        : bool Arrayf.t ;       (* all false: used to save space *)
    zeroes        : int Arrayf.t ;        (* all zero: used to save space *)
    loop          : rank Arrayf.t ;      	(* ranks in a loop, skipping me *)
    async         : (Group.id * Endpt.id) (* info for finding async *)
  }  
  
  (* LOCAL: create local record based on view state and endpt.
   *)
  val local : debug -> Endpt.id -> state -> local
  
  val redirect_async : debug -> Group.id * Endpt.id -> local -> local
  
  (**************************************************************)
  
  (* VIEW.FULL: a full view state contains both local and common
   * information.
   *)
  type full = local * state
  
  (* SINGLETON: Create full view state for singleton view.
   *)
  val singleton :
    Security.key ->			(* security key *)
    Proto.id ->				(* protocol *)
    Group.id ->				(* group *)
    Endpt.id ->				(* endpt *)
    Addr.set ->				(* addresses *)
    Time.t ->				(* current time *)
    full
  
  (* STRING_OF_FULL: Display function for view state records.
   *)
  val string_of_full : full -> string
  
  (* CHECK: check some conditions on the sanity of the 
   * view state.
   *)
  val check : debug -> full -> unit
  
  (**************************************************************)
  
  val endpt_full : full -> Endpt.full 
  
  val coord_full : state -> Endpt.full
  
  (**************************************************************)
  
  (* MERGE: merge a list of view states together.  The fields
   * view, client, address, and out_of_date are taken from the
   * constituent views.  The prev_ids are taken from each of
   * view states (in order).  The ltime is the successor of the
   * maximum of the ltimes.  The other fields are from the view
   * state at the head of the list. 
   *)
  val merge : state list -> state
  
  (* FAIL: takes a view state and list of failed ranks and
   * strips the failed members from the 4 array fields.
   *)
  val fail : state -> bool Arrayf.t -> state
  
  (**************************************************************)
end

module Conn : sig
  (**************************************************************)
  (* CONN.MLI : communication connection ids *)
  (* Author: Mark Hayden, 12/95 *)
  (**************************************************************)
  
  (* Identifier used for communication routing.
   *)
  type id
  
  type kind = Cast | Send (*| Other*)
  
  (* Set of connection identifiers used to communicate
   * with peers.
   *)
  type t
  type key
  type recv_info = id * kind 
  
  (* Constructor.
   *)
  val create : 
    Trans.rank ->
    Version.id ->
    Group.id -> 
    View.id -> 
    Stack_id.t -> 
    Proto.id -> 
    View.t -> 
    t
  
  val key	     	: t -> key
  val pt2pt_send 	: t -> Trans.rank -> id
  val multi_send 	: t -> id
  val gossip 	: t -> id
  val all_recv    : t -> recv_info list
  
  (*
  val string_of_key : key -> string
  val string_of_t : t -> string
  *)
  
  (* Display functions.
   *)
  val string_of_id : id -> string
  
  val string_of_kind : kind -> string
  
  (**************************************************************)
  (* Create a 16-byte MD5 hash of an id.
   *)
  val hash_of_id : id -> Buf.digest
  
  val hash_of_key : Version.id -> Group.id -> Proto.id -> Buf.digest
  
  (* A hack.  Squashes sender field in id to an illegal value.
   * and return the original field.  Used in Router.scale.
   *)
  val squash_sender : id -> (Trans.rank option * id)
  
  (**************************************************************)
  val ltime : id -> Trans.ltime
  (**************************************************************)
end

module Route : sig
  (**************************************************************)
  (* ROUTE.MLI *)
  (* Author: Mark Hayden, 12/95 *)
  (**************************************************************)
  open Trans
  (* open Buf *)
  (**************************************************************)
  
  type pre_processor =
    | Unsigned of (rank -> Obj.t option -> seqno -> Iovecl.t -> unit)
    | Signed of (bool -> rank -> Obj.t option -> seqno -> Iovecl.t -> unit)
  
  (**************************************************************)
  
  type handlers
  val handlers : unit -> handlers
  
  (* The central delivery functions of Ensemble.  All incoming
   * messages go through here. the format is: (len,buf,iovec).
   * buf - a preallocated ML buffer.
   * iovec - a user-land iovec.
   *)
  val deliver : handlers -> Buf.t -> Buf.ofs -> Buf.len -> Iovecl.t -> unit
  (**************************************************************)
  
  (* transmit an Ensemble packet, this includes the ML part, and a
   * user-land iovecl.
   *)
  type xmitf = Buf.t -> Buf.ofs -> Buf.len -> Iovecl.t -> unit
  
  (* Type of routers. ['xf] is the type of a message send function. 
   *)
  type 'xf t
  
  val debug : 'xf t -> debug
  val secure : 'xf t -> bool
  val blast : 'xf t -> xmitf -> Security.key -> Conn.id -> 'xf
  val install : 'xf t -> handlers -> Conn.key -> Conn.recv_info list -> 
      Security.key -> (Conn.kind -> bool -> 'xf) -> unit
  val remove : 'xf t -> handlers -> Conn.key -> Conn.recv_info list -> unit
  
  (**************************************************************)
  
  (* Security enforcement.
   *)
  val set_secure : unit -> unit
  
  val security_check : 'a t -> unit
  
  (**************************************************************)
  
  type id =
    | UnsignedId
    | SignedId
  
  val id_of_pre_processor : pre_processor -> id
  
  (**************************************************************)
  
  (* Create a router.
   *)
  val create :
    debug ->
    bool -> (* secure? *)
    ((bool -> 'xf) -> pre_processor) ->
    (Conn.id -> Buf.t) ->			(* packer *)
    ((Conn.id * Buf.t * Security.key * pre_processor) Arrayf.t ->
      (Buf.t -> Buf.ofs -> Buf.len -> Iovecl.t -> unit) Arrayf.t) -> (* merge *)
    (xmitf -> Security.key -> Buf.t -> Conn.id -> 'xf) ->  (* blast *)
    'xf t
  
  (**************************************************************)
  
  (* Logging functions.  Called from various places.
   *)
  val drop : (unit -> string) -> unit (* For tracing message drops: ROUTED *)
  val info : (unit -> string) -> unit (* For tracing connection ids: ROUTEI *)
  
  (**************************************************************)
  (* Helper functions for the various routers.
   *)
  val merge1 : ('a -> unit) Arrayf.t -> 'a -> unit
  val merge2 : ('a -> 'b -> unit) Arrayf.t -> 'a -> 'b -> unit
  val merge3 : ('a -> 'b -> 'c -> unit) Arrayf.t -> 'a -> 'b -> 'c -> unit
  val merge4 : ('a -> 'b -> 'c -> 'd -> unit) Arrayf.t -> 'a -> 'b -> 'c -> 'd -> unit
  
  (* See comments in code.
   *)
  val group : ('a * 'b) Arrayf.t -> ('a * 'b Arrayf.t) Arrayf.t
  val merge1iov : (Iovecl.t -> unit) Arrayf.t -> Iovecl.t -> unit
  val merge2iov : ('a -> Iovecl.t -> unit) Arrayf.t -> 'a -> Iovecl.t -> unit
  val merge2iovr : (Iovecl.t -> 'a -> unit) Arrayf.t -> Iovecl.t -> 'a -> unit
  val merge3iov : ('a -> 'b -> Iovecl.t -> unit) Arrayf.t -> 'a -> 'b -> Iovecl.t -> unit
  val merge4iov : ('a -> 'b -> 'c -> Iovecl.t -> unit) Arrayf.t -> 'a -> 'b -> 'c -> Iovecl.t -> unit
  
  (**************************************************************)
  
  val pack_of_conn : Conn.id -> Buf.digest
  
  (**************************************************************)
end

module Async : sig
  (**************************************************************)
  (* ASYNC.MLI *)
  (* Author: Mark Hayden, 4/97 *)
  (**************************************************************)
  
  type t
  
  val create : Sched.t -> t
  
  (* Async.add: called by "receiver" to register a callback.
   * It returns disable function.
   *)
  val add : t -> (Group.id * Endpt.id) -> (unit -> unit) -> (unit -> unit) 
  
  (* Find is called by "sender" to generate new callback.
   *)
  val find : t -> (Group.id * Endpt.id) -> (unit -> unit)
  
end

module Real : sig
  (**************************************************************)
  (* REAL.MLI *)
  (* Author: Mark Hayden, 3/96 *)
  (**************************************************************)
  
  val export_socks : Hsys.socket Arrayf.t ref
  val install_blocker : (Time.t -> unit) -> unit
end

module Alarm : sig
  (**************************************************************)
  (* ALARM.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* ALARM: a record for requesting timeouts on a particular
   * callback.  
   *)
  type alarm
  
  val disable : alarm -> unit
  val schedule : alarm -> Time.t -> unit
  
  (**************************************************************)
  
  (* ALARM.T: The type of alarms.
   *)
  type t
  
  (**************************************************************)
  
  type poll_type = SocksPolls | OnlyPolls
  
  val name	: t -> string		(* name of alarm *)
  val gettime 	: t -> Time.t		(* get current time *)
  val alarm 	: t -> (Time.t -> unit) -> alarm (* create alarm object *)
  val check 	: t -> unit -> bool	(* check if alarms have timed out *)
  val min 	: t -> Time.t		(* get next alarm to go off *)
  val add_sock_recv : t -> debug -> Hsys.socket -> Hsys.handler -> unit (* add a socket *)
  val rmv_sock_recv : t -> Hsys.socket -> unit (* remove socket *)
  val add_sock_xmit : t -> debug -> Hsys.socket -> (unit->unit) -> unit (* add a socket *)
  val rmv_sock_xmit : t -> Hsys.socket -> unit (* remove socket *)
  val add_poll 	: t -> string -> (bool -> bool) -> unit (* add polling fun *)
  val rmv_poll 	: t -> string -> unit	(* remove polling function *)
  val block 	: t -> unit		(* block until next timer/socket input *)
  val poll 	: t -> poll_type -> unit -> bool (* poll for socket data *)
  val handlers    : t -> Route.handlers
  val sched       : t -> Sched.t
  val async       : t -> Async.t
  val unique      : t -> Unique.t
  val local_xmits : t -> Route.xmitf
  
  (**************************************************************)
  (**************************************************************)
  (* For use only by alarms.
   *)
  
  type gorp = Unique.t * Sched.t * Async.t * Route.handlers
  
  val create :
    string ->				(* name *)
    (unit -> Time.t) ->			(* gettime *)	
    ((Time.t -> unit) -> alarm) ->	(* alarm *)	      
    (unit -> bool) ->			(* check *)
    (unit -> Time.t) ->			(* min *)
    (string -> Hsys.socket -> Hsys.handler -> unit) -> (* add_sock *)	
    (Hsys.socket -> unit) ->		(* rmv_sock *)
    (string -> Hsys.socket -> (unit->unit) -> unit) -> (* add_sock_xmit *)	
    (Hsys.socket -> unit) ->		(* rmv_sock_xmit *)
    (unit -> unit) ->			(* block *)
    (string -> (bool -> bool) -> unit) ->	(* add_poll *)	
    (string -> unit) ->			(* rmv_poll *)
    (poll_type -> unit -> bool) ->	(* poll	*)
    gorp ->
    t
  
  val alm_add_poll	: string -> (bool -> bool) -> ((bool -> bool) option)
  val alm_rmv_poll	: string -> ((bool -> bool) option)
  
  val wrap : ((Time.t -> unit) -> Time.t -> unit) -> t -> t
  val c_alarm : (unit -> unit) -> (Time.t -> unit) -> alarm
  
  (**************************************************************)
  
  (* Installation and management of alarms.
   * 
   * [OR]: This has been moved back here, away from the elink 
   * module. I think dynamic linking should be done by the caml
   * folk, not us. 
  *)
  
  type id = string
  val install  : id -> (gorp -> t) -> unit
  val choose   : id -> gorp -> t
  val get_hack : unit -> t
  
  (**************************************************************)
  
  (* Install a unique port number. 
   * OR: moved here from Appl.
  *)
  val install_port : Trans.port -> unit
  
  (**************************************************************)
end

module Auth : sig
  (**************************************************************)
  (* AUTH.MLI *)
  (* Authors: Mark Hayden, Ohad Rodeh, 8/96 *)
  (**************************************************************)
  (* This file gives a generic interface to authentication
   * services. *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type t
  
  type clear = string 			(* cleartext *)
  type cipher = string 			(* ciphertext *)
  
  val lookup : Addr.id -> t
  
  val principal : t -> Addr.id -> string -> Addr.t
  (**************************************************************)
  
  (* This is assumed to be in base64. 
  *)
  type ticket
  
  val string_of_ticket : ticket -> string
  val ticket_of_string : string -> ticket
  
  val ticket : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set(*him*) -> clear -> ticket option
  
  val bckgr_ticket : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set(*him*) ->
   	clear -> Alarm.t -> (ticket option -> unit) -> unit
  
  val check : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set (* him *) -> ticket -> clear option
  
  val bckgr_check : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set (*him*) -> 
  	ticket -> Alarm.t -> (clear option -> unit) -> unit
  
  type data = 
    | Clear of clear option
    | Ticket  of ticket option
  (**************************************************************)
  
  val create : 
    name ->
    (Addr.id -> string -> Addr.t) ->
    (Addr.id -> Addr.set -> Addr.set -> clear -> cipher option) ->
    (Addr.id -> Addr.set -> Addr.set -> clear -> Alarm.t -> 
      (cipher option -> unit) -> unit) -> 
    (Addr.id -> Addr.set -> Addr.set -> cipher -> clear option) ->
    (Addr.id -> Addr.set -> Addr.set -> cipher -> Alarm.t -> 
      (clear option -> unit) -> unit) -> 
    t
  
  val install : Addr.id -> t -> unit
  
  (**************************************************************)
end

module Domain : sig
  (**************************************************************)
  (* DOMAIN.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* DOMAIN.T: The type of a communication domain.
   *)
  
  type t
  
  (* DEST: this specifies the destinations to use in xmit and
   * xmitv.  For pt2pt xmits, we give a list of endpoint
   * identifiers to which to send the message.  For
   * multicasts, we give a group address and a boolean value
   * specifying whether loopback is necessary.  If no loopback
   * is requested then the multicast may not be delivered to
   * any other processes on the same host as the sender.
   *)
  
  (* Note that significant preprocessing may be done on the
   * destination values.  For optimal performance, apply the
   * destination to an xmit outside of your critical path.
   *)
  
  type loopback = bool
  
  type dest =
  | Pt2pt of Addr.set Arrayf.t
  | Mcast of Group.id * loopback
  | Gossip of Group.id
  
  (**************************************************************)
  
  type handle
  
  (**************************************************************)
  (* Operations on domains.
   *)
  
  val name 	: t -> string		(* name of domain *)
  val addr	: t -> Addr.id -> Addr.t (* create a local addresss *)
  val enable 	: t -> Addr.id -> Group.id -> Addr.set -> View.t -> handle
  val disable 	: handle -> unit
  val xmit 	: handle -> dest -> Route.xmitf option (* how to xmit *)
  
  (**************************************************************)
  
  (* Create a domain.
   *)
  val create : 
    name ->				(* name of domain *)
    (Addr.id -> Addr.t) ->		(* create endpoint address *)
    (Addr.id -> Group.id -> Addr.set -> View.t -> handle) -> (* enable new transport *)
    t
  
  val handle :
    (unit -> unit) -> (* disable transport *)
    (dest -> Route.xmitf option) ->  (* xmit *)
    handle
  
  val string_of_dest : dest -> string
  
  (**************************************************************)
  (* Domain management.
   *)
  
  val of_mode : Alarm.t -> Addr.id -> t
  val install : Addr.id -> (Alarm.t -> t) -> unit
  (**************************************************************)
end

module Event : sig
  (**************************************************************)
  (* EVENT.MLI *)
  (* Author: Mark Hayden, 4/95 *)
  (* Based on Horus events by Robbert vanRenesse *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
    (* Up and down events *)
  type t
  type up = t
  type dn = t
  
  (**************************************************************)
  
    (* Event types *)
  type typ =
      (* These events have messages associated with them. *)
    | ECast of Iovecl.t			(* Multicast message *)
    | ESend of Iovecl.t			(* Pt2pt message *)
    | ECastUnrel of Iovecl.t   	        (* Unreliable multicast message *)
    | ESendUnrel of Iovecl.t		(* Unreliable pt2pt message *)
  
    (* These events have Buf.t messages, not iovec's. 
     *)
    | EMergeRequest			(* Request a merge *)
    | EMergeGranted			(* Grant a merge request *)
    | EMergeDenied			(* Deny a merge request *)
    | EMergeFailed			(* Merge request failed *)
    | EOrphan				(* Message was orphaned *)
  
      (* These types do not have messages. *)
    | EAccount				(* Output accounting information *)
    | EAsync				(* Asynchronous application event *)
    | EBlock				(* Block the group *)
    | EBlockOk				(* Acknowledge blocking of group *)
    | EDump				(* Dump your state (debugging) *)
    | EElect				(* I am now the coordinator *)
    | EExit				(* Disable this stack *)
    | EFail				(* Fail some members *)
    | EGossipExt				(* Gossip message *)
    | EGossipExtDir			(* Gossip message directed at particular address *)
    | EInit				(* First event delivered *)
    | ELeave				(* A member wants to leave *)
    | ELostMessage			(* Member doesn't have a message *)
    | EMigrate				(* Change my location *)
    | EPresent                            (* Members present in this view *)
    | EPrompt				(* Prompt a new view *)
    | EProtocol				(* Request a protocol switch *)
    | ERekey				(* Request a rekeying of the group *)
    | ERekeyPrcl				(* The rekey protocol events *)
    | ERekeyPrcl2				(*                           *)
    | EStable				(* Deliver stability down *)
    | EStableReq				(* Request for stability information *)
    | ESuspect				(* Member is suspected to be faulty *)
    | ESystemError			(* Something serious has happened *)
    | ETimer				(* Request a timer *)
    | EView				(* Notify that a new view is ready *)
    | EXferDone				(* Notify that a state transfer is complete *)
    | ESyncInfo
        (* Ohad, additions *)
    | ESecureMsg				(* Private Secure messaging *)
    | EChannelList			(* passing a list of secure-channels *)
    | EFlowBlock				(* Blocking/unblocking the application for flow control*)
  (* Signature/Verification with PGP *)
    | EAuth
  
    | ESecChannelList                     (* The channel list held by the SECCHAN layer *)
    | ERekeyCleanup
    | ERekeyCommit 
  
  (* Fuzzy related events *)
    | EFuzzy				(* Report a change of fuzziness *)
    | EFuzzyRequest		(* Request a change of fuzziness *)
    | EFuzzyAuthorize	(* Authorize a change of fuzziness *)
  
  (**************************************************************)
  (* These are compact descriptions of types. Used for optimizing
   * headers in event.ml.
  *)
  type compact_typ = 
    | C_ECast
    | C_ESend
    | C_EOther
  
  (**************************************************************)
  
  type field =
        (* Common fields *)
    | Type	of typ			(* type of the message*)
    | Peer	of rank			(* rank of sender/destination *)
    | ApplMsg				(* was this message generated by an appl? *)
  
        (* Uncommon fields *)
    | Address     of Addr.set		(* new address for a member *)
    | Failures	of bool Arrayf.t	(* failed members *)
    | Presence    of bool Arrayf.t        (* members present in the current view *)
    | Suspects	of bool Arrayf.t        (* suspected members *)
    | SuspectReason of string		(* reasons for suspicion *)
    | Stability	of seqno Arrayf.t	(* stability vector *)
    | NumCasts	of seqno Arrayf.t	(* number of casts seen *)
    | Contact	of Endpt.full * View.id option (* contact for a merge *)
    | HealGos	of Proto.id * View.id * Endpt.full * View.t * Hsys.inet list (* HEAL gossip *)  
    | SwitchGos	of Proto.id * View.id * Time.t  (* SWITCH gossip *)
    | ExchangeGos	of string		(* EXCHANGE gossip *)
    | MergeGos	of (Endpt.full * View.id option) * seqno * typ * View.state (* INTER gossip *)
    | ViewState	of View.state		(* state of next view *)
    | ProtoId	of Proto.id		(* protocol id (only for down events) *)
    | Time        of Time.t		(* current time *)
    | Alarm       of Time.t		(* for alarm requests *)(* BUG: this is not needed *)
    | ApplCasts   of seqno Arrayf.t
    | ApplSends   of seqno Arrayf.t
    | DbgName     of string
  
        (* Flags *)
    | NoTotal				(* message is not totally ordered*)
    | ServerOnly				(* deliver only at servers *)
    | ClientOnly				(* deliver only at clients *)
    | NoVsync
    | ForceVsync
    | Fragment				(* Iovec has been fragmented *)
  
        (* Debugging *)
    | History	of string		(* debugging history *)
  
        (* Ohad -- Private Secure Messaging *)
    | SecureMsg of Buf.t
    | ChannelList of (rank * Security.key) list
  	
        (* Ohad -- interaction between Mflow, Pt2ptw, Pt2ptwp and the application*)
    | FlowBlock of rank option * bool
  
    (* Signature/Verification with Auth *)
    | AuthData of Addr.set * Auth.data
  
    (* Information passing between optimized rekey layers
     *)
    | AgreedKey of Security.key
  
    | SecChannelList of Trans.rank list  (* The channel list held by the SECCHAN layer *)
    | SecStat of int                      (* PERF figures for SECCHAN layer *)
    | RekeyFlag of bool                   (* Do a cleanup or not *)
    | TTL of int                          (* Time-to-live *)
  (* Fuzzy related fields *)
    | LocalFuzziness	of seqno Arrayf.t	(* local fuzziness vector *)
    | GlobalFuzziness of seqno Arrayf.t	(* global fuzziness vector *)
  (* The following is part of the EStable event *)
    | LocalFuzzyStability of seqno Arrayf.t (* stable messages wrt local fuzzy nodes *)
    | GlobalFuzzyStability of seqno Arrayf.t (* stable messages wrt global fuzzy nodes *)
    | OwnAcked of seqno Arrayf.t (* the acks I got from each node for my messages *)
  
  (**************************************************************)
  
    (* Directed events. *)
  type dir = Up of t | Dn of t
  
  type ('a,'b) dirm = UpM of up * 'a | DnM of dn * 'b
  
  (**************************************************************)
  
    (* Constructor *)
  val create	: debug -> typ -> field list -> t
  
  (**************************************************************)
  
    (* Modifier *)
  val set		: debug -> t -> field list -> t
  
  (**************************************************************)
  
    (* Modifier *)
  val set_typ	: debug -> t -> typ -> t
  
  (**************************************************************)
  
    (* Copier *) 
  val copy	: debug -> t -> t
  
  (**************************************************************)
  
    (* Destructor, free the iovec ref-count *)
  val free	: debug -> t -> unit
  
  (**************************************************************)
  
    (* Sanity checkers *)
  val upCheck	: debug -> t -> unit
  val dnCheck	: debug -> t -> unit
  
  (**************************************************************)
  
    (* Pretty printer *)
  val to_string	: t -> string
  val string_of_type : typ -> string
  
  (**************************************************************)
  
    (* Special constructors *)
  
  val bodyCore		: debug -> typ -> origin -> t
  val castEv		: debug	-> t
  val castUnrel	        : debug	-> t
  val castUnrelIov	: debug	-> Iovecl.t -> t
  val castIov		: debug -> Iovecl.t -> t
  val castIovAppl		: debug -> Iovecl.t -> t
  val castPeerIov 	: debug -> rank -> Iovecl.t -> t
  val castPeerIovAppl 	: debug -> rank -> Iovecl.t -> t
  val sendPeer		: debug -> rank	-> t
  val sendPeerIov         : debug -> rank -> Iovecl.t -> t
  val sendPeerIovAppl	: debug -> rank -> Iovecl.t -> t
  val sendUnrelPeer       : debug -> rank -> t
  val sendUnrelPeerIov    : debug -> rank -> Iovecl.t -> t
  val suspectReason       : debug -> bool Arrayf.t -> debug -> t
  val timerAlarm		: debug -> Time.t -> t
  val timerTime		: debug -> Time.t -> t
  val dumpEv              : debug -> t
  
  (**************************************************************)
  
    (* Accessors *)
  
  val getAddress     	: t -> Addr.set
  val getAlarm		: t -> Time.t
  val getApplMsg	        : t -> bool
  val getApplCasts	: t -> seqno Arrayf.t
  val getApplSends  	: t -> seqno Arrayf.t
  val getClientOnly	: t -> bool
  val getContact		: t -> Endpt.full * View.id option
  val getExtend     	: t -> field list
  val getExtendFail     	: (field -> 'a option) -> debug -> t -> 'a
  val getExtender     	: (field -> 'a option) -> 'a -> t -> 'a
  val getExtendOpt	: t -> (field -> bool) -> unit
  val getFailures		: t -> bool Arrayf.t
  val getFragment		: t -> bool
  val getIov		: t -> Iovecl.t option
  val getNoTotal		: t -> bool
  val getNoVsync          : t -> bool
  val getForceVsync       : t -> bool 
  val getNumCasts		: t -> seqno Arrayf.t
  val getPeer		: t -> origin
  val getDbgName          : t -> string
  val getPresence         : t -> bool Arrayf.t
  val getProtoId		: t -> Proto.id
  val getServerOnly	: t -> bool
  val getStability	: t -> seqno Arrayf.t
  val getSuspectReason	: t -> string
  val getSuspects		: t -> bool Arrayf.t
  val getTime		: t -> Time.t
  val getType		: t -> typ
  val getCompactType	: t -> compact_typ
  val getViewState	: t -> View.state
  val getSecureMsg        : t -> Buf.t
  val getChannelList      : t -> (Trans.rank * Security.key) list
  val getFlowBlock        : t -> rank option * bool	
  val getAuthData         : t -> Addr.set * Auth.data
  val getSecChannelList   : t -> Trans.rank list
  val getSecStat          : t -> int 
  val getRekeyFlag        : t -> bool 
  val getTTL              : t-> int option
  
  val setSendIovFragment  : debug -> t -> Iovecl.t -> t
  val setCastIovFragment  : debug -> t -> Iovecl.t -> t
  val setNoTotal  	: debug -> t -> t
  val getAgreedKey        : t -> Security.key 
  val setPeer        	: debug -> t -> rank -> t
  val setSendUnrelPeer   	: debug -> t -> rank -> t
  
  val getLocalFuzziness	: t -> seqno Arrayf.t
  val getGlobalFuzziness	: t -> seqno Arrayf.t
  val getLocalFuzzyStability	: t -> seqno Arrayf.t
  val getGlobalFuzzyStability	: t -> seqno Arrayf.t
  val getOwnAcked	: t -> seqno Arrayf.t
  (**************************************************************)
  
  
end

module Property : sig
  (**************************************************************)
  (* PROPERTY.MLI *)
  (* Author: Mark Hayden, 12/96 *)
  (**************************************************************)
  
  type id =
    | Agree				(* agreed (safe) delivery *)
    | Gmp					(* group-membership properties *)
    | Sync				(* view synchronization *)
    | Total				(* totally ordered messages *)
    | Heal				(* partition healing *)
    | Switch				(* protocol switching *)
    | Auth				(* authentication *)
    | Causal				(* causally ordered broadcasts *)
    | Subcast				(* subcast pt2pt messages *)
    | Frag				(* fragmentation-reassembly *)
    | Debug				(* adds debugging layers *)
    | Scale				(* scalability *)
    | Xfer				(* state transfer *)
    | Cltsvr				(* client-server management *)
    | Suspect				(* failure detection *)
    | Flow				(* flow control *)
    | Migrate				(* process migration *)
    | Privacy				(* encryption of application data *)
    | Rekey				(* support for rekeying the group *)
    | Primary				(* primary partition detection *)
    | Local				(* local delivery of messages *)
    | Slander				(* members share failure suspiciions *)
    | Asym			        (* overcome asymmetry *)
  
      (* The following are not normally used.
       *)
    | Drop				(* randomized message dropping *)
    | Pbcast				(* Hack: just use pbcast prot. *)
    | Zbcast                              (* Use Zbcast protocol. *)
    | Gcast                               (* Use gcast protocol. *)
    | Dbg                                 (* on-line modification of network topology *)
    | Dbgbatch                            (* batch mode network emulation *)
    | P_pt2ptwp                           (* Use experimental pt2pt flow-control protocol *)
    (* This is a list of id's, it includes: {Gmp,Sync,Heal,Switch,Frag,Suspect,Flow,Slander}
     *)
    | Vsync 
  
  (* Create protocol with desired properties.
   *)
  val choose : id list -> Proto.id
  
  (* Common property lists.
   *)
  val vsync : id list			(* Fifo virtual synchrony *)
  val causal : id list			(* vsync + Causal *)
  val total : id list			(* vsync + Total *)
  val scale : id list			(* vsync + Scale *)
  val fifo : id list			(* only Fifo (no membership) *)
  val local : id list                     (* vsync + Local *)
  
  val string_of_id : id -> string
  val id_of_string : string -> id
  val all : unit -> id array
  
  (**************************************************************)
  
  (* Strip unnecessary properties for use of groupd.
   *)
  val strip_groupd : id list -> id list
  
  (**************************************************************)
end

module Appl_intf : sig
  (**************************************************************)
  (* APPL_INTF.ML: application interface *)
  (* Author: Mark Hayden, 8/95 *)
  (* See documentation for a description of this interface *)
  (**************************************************************)
  open Trans
  (* open Util *)
  (**************************************************************)
  
  (* Some type aliases.
   *)
  type dests = rank array
  
  (**************************************************************)
  (* ACTION: The type of actions an application can take.
   * These are typically returned from callbacks as lists of
   * actions to be taken.
  
   * [NOTE: XferDone, Protocol, Rekey, and Migrate are not
   * implemented by all protocol stacks.  Dump and Block are
   * undocumented actions used for internal Ensemble
   * services.]
  
   * Cast(msg): Broadcast a message to entire group
  
   * Send(dests,msg): Send a message to subset of group.
  
   * Leave: Leave the group.
  
   * Prompt: Prompt for a view change.
  
   * Suspect: Tell the protocol stack about suspected failures
   * in the group.
  
   * XferDone: Mark end of a state transfer.
  
   * Protocol(protocol): Request a protocol switch.  Will
   * cause a view change to new protocol stack.
  
   * Migrate(addresses): Change address list for this member.
   * Will cause a view change.
  
   * Rekey: Request that the group be rekeyed.
  
   * Timeout(time): Request a timeout at a particular time.
   * The timeout takes the form of a heartbeat callback.
   * Currently not supported.
  
   * Dump: Undefined (for debugging purposes)
  
   * Block: Controls synchronization of view changes.  Not
   * for casual use.
   *)
  type control =
    | Leave
    | Prompt
    | Suspect of rank list
  
    | XferDone
    | Rekey of bool 
    | Protocol of Proto.id
    | Migrate of Addr.set
    | Timeout of Time.t
  
    | Dump
    | Block of bool
    | No_op
  
  type ('cast_msg,'send_msg) action =
    | Cast of 'cast_msg
    | Send of dests * 'send_msg
    | Send1 of rank * 'send_msg
    | Control of control
  
  val string_of_control : control -> string
  val string_of_action : ('a,'b) action -> string
  
  val action_array_map : 
    ('a -> 'b) -> ('c -> 'd) -> 
      ('a,'c) action array -> ('b,'d) action array
  
  (**************************************************************)
  
  (* This is a new version of the application interface.
   * We will be slowly transitioning to it because it
   * provides better performance and is often easier to
   * use.
   * 
   * OR: As of version 1.3, only the new interface is supported.
   *)
  
  module New : sig
    type cast_or_send = C | S
    type blocked = U | B
  
    type 'msg naction = ('msg,'msg) action
  
    type 'msg handlers = {
      flow_block : rank option * bool -> unit ;
      block : unit -> 'msg naction array ;
      heartbeat : Time.t -> 'msg naction array ;
      receive : origin -> blocked -> cast_or_send -> 'msg -> 'msg naction array ;
      disable : unit -> unit
    } 
  
    type 'msg full = {
      heartbeat_rate : Time.t ;
      install : View.full -> ('msg naction array) * ('msg handlers) ;
      exit : unit -> unit
    } 
  
    type t = Iovecl.t full
    type 'msg power = ('msg * Iovecl.t) full
  
    val string_of_blocked : blocked -> string
    val string_of_cs : cast_or_send -> string
  
    (* A Null handler for applications.
     *)
    val null : 'msg -> 'msg naction array
  
    val full : 'msg full -> t
  
    val failed_handlers : 'msg handlers
  end
  
  type appl_lwe_header =
    | LCast of origin
    | LSend of origin * rank array
  
  type appl_multi_header =
    int
  
  (**************************************************************)
end

module Appl_handle : sig
  (**************************************************************)
  (* APPL_HANDLE.MLI *)
  (* Author: Mark Hayden, 10/97 *)
  (**************************************************************)
  open Trans
  (* open Util *)
  (**************************************************************)
  
  (* BUG: handle and handle_gen should be opaque.
   *)
  type handle     = { mutable endpt : Endpt.id ; mutable rank : int }
  type origin 	= handle
  type rank       = handle
  type dests 	= handle array
  type handle_gen = unit
  
  (**************************************************************)
  
  type ('cast_msg, 'send_msg) action =
    | Cast of 'cast_msg
    | Send of dests * 'send_msg
    | Control of Appl_intf.control
  
  (**************************************************************)
  
  (* Create a new handle give a handle generator and endpoint.
   *)
  val handle : handle_gen -> debug -> Endpt.id -> handle
  
  (* Check if handle is valid in a view.
   *)
  val is_valid : handle -> View.state -> bool
  
  val handle_hack : debug -> Endpt.id -> handle
  
  val string_of_handle : handle -> string
  
  val endpt_of_handle : handle -> Endpt.id
  
  val handle_eq : handle -> handle -> bool
  
  (**************************************************************)
  
  module Old : sig
    type (
      'cast_msg,
      'send_msg,
      'merg_msg,
      'view_msg
    ) full = {
      recv_cast 		: origin -> 'cast_msg ->
        ('cast_msg,'send_msg) action array ;
  
      recv_send 		: origin -> 'send_msg ->
        ('cast_msg,'send_msg) action array ;
  
      heartbeat_rate	: Time.t ;
  
      heartbeat 		: Time.t ->
        ('cast_msg,'send_msg) action array ;
  
      block 		: unit ->
        ('cast_msg,'send_msg) action array ;
  
      block_recv_cast 	: origin -> 'cast_msg -> unit ;
      block_recv_send 	: origin -> 'send_msg -> unit ;
      block_view          : View.full -> (Endpt.id * 'merg_msg) list ;
      block_install_view  : View.full -> 'merg_msg list -> 'view_msg ;
      unblock_view 	: View.full -> 'view_msg ->
        ('cast_msg,'send_msg) action array ;
  
      exit 		: unit -> unit
    }
  
    (*val f : ('a,'b,'c,'d) full -> handle_gen * ('a,'b,'c,'d) Appl_intf.Old.full*)
  end
  
  (**************************************************************)
  
  module New : sig
    type cast_or_send = Appl_intf.New.cast_or_send = C | S
    type blocked = Appl_intf.New.blocked = U | B
  
    type 'msg naction = ('msg,'msg) action
  
    type 'msg handlers = {
      block : unit -> 'msg naction array ;
      heartbeat : Time.t -> 'msg naction array ;
      receive : origin -> blocked -> cast_or_send -> 'msg -> 'msg naction array ;
      disable : unit -> unit
    } 
  
    type 'msg full = {
      heartbeat_rate : Time.t ;
      install : View.full -> handle Arrayf.t -> ('msg naction array) * ('msg handlers) ;
      exit : unit -> unit
    } 
  
    (*val f : 'msg full -> handle_gen * 'msg Appl_intf.New.full*)
  end
  
  (**************************************************************)
end

module Layer : sig
  (**************************************************************)
  (* LAYER.MLI *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  open Trans
  
  (**************************************************************)
  
  type 'a saved = 'a option ref
  
  type roaming_t = {
    mutable location : location_t;  
    mutable prev_loc : location_t;
    mutable new_loc  : location_t;
   (*  mutable speed    : location_t; *) (* TODO:  Allow for randomly chosen speeds *)
    mutable time_to_dest : Time.t;
    mutable duration_to_dest : float ;
    mutable wait_at_dest : Time.t
  }
  (**************************************************************)
  
  type ('a,'b,'c) handlers_out = {
    up_out	: Event.up -> 'c -> unit ;
    upnm_out	: Event.up -> unit ;
    dn_out 	: Event.dn -> 'c -> 'b -> unit ;
    dnlm_out	: Event.dn -> 'a -> unit ;
    dnnm_out	: Event.dn -> unit 
  }
  
  type ('a,'b,'c) handlers_in = {
    up_in 	: Event.up -> 'c -> 'b -> unit ;
    uplm_in 	: Event.up -> 'a -> unit ;
    upnm_in 	: Event.up -> unit ;	
    dn_in 	: Event.dn -> 'c -> unit ;
    dnnm_in 	: Event.dn -> unit
  }
  
  type ('local,'hdr,'abv) full =
    ('local,'hdr,'abv) handlers_out ->
    ('local,'hdr,'abv) handlers_in
  
  (**************************************************************)
  (* What messages look like in this architecture.
   *)
  type ('local,'hdr,'abv) msg =
    (* These come first in order to enable some hacks.
     *)
    | Local_nohdr
    | Local_seqno of Trans.seqno
  
    | NoMsg
    | Local of 'local
    | Full of 'hdr * 'abv
    | Full_nohdr of 'abv
  
  val string_of_msg :
    ('local -> string) -> ('hdr -> string) -> ('abv -> string) ->
      ('local,'hdr,'abv) msg -> string
  
  (**************************************************************)
  
  type ('local,'hdr) optimize =
    | NoOpt
    | LocalNoHdr of 'local
    | FullNoHdr of 'hdr
    | LocalSeqno of 'hdr * Event.compact_typ * ('hdr -> Trans.seqno option) * (Trans.seqno option -> 'hdr)
  
  (**************************************************************)
  (* Message composition functions (for bypass code).
   *)
  val compose_msg : 'abv -> 'hdr -> ('local,'hdr,'abv) msg
  val local_msg : 'local -> ('local,'hdr,'abv) msg
  val no_msg : unit -> ('local,'hdr,'abv) msg
  
  (**************************************************************)
  
  type state = {
    interface        : Appl_intf.New.t ;
    switch	   : Time.t saved ;
    exchange         : (Addr.set -> bool) option ;
    roaming_r          : roaming_t ref ;
    manet_disconnected : bool ref ;
    secchan          : (Endpt.id * Security.cipher) list ref ; (* State for SECCHAN *)
  
    dyn_tree         : Mrekey_dt.t ref ;   (* State for REKEY_DT *)
    (* dh_key           : Shared.DH.key option ref ; *)
    next_cleanup     : Time.t ref ;
  
    (* A way for applications using the Ensemble server to pipe messages directly
     * into the top-appl layer. Should -not- be used for any other purpose
     *)
    handle_action    : ((Iovecl.t, Iovecl.t) Appl_intf.action -> unit) ref
  }
  
  val new_state : Appl_intf.New.t -> state
  
  val set_exchange : (Addr.set -> bool) option -> state -> state
  
  val reset_state : state -> unit
  
  (**************************************************************)
  (* Type of exported layers. (Exported for bypass code.)
   *)
  
  type ('bel,'abv) handlers_lout = {
    up_lout	: Event.up -> 'bel -> unit ;
    dn_lout 	: Event.dn -> 'abv -> unit
  }
  
  type ('bel,'abv) handlers_lin  = {
    up_lin 	: Event.up -> 'abv -> unit ;
    dn_lin 	: Event.dn -> 'bel -> unit 
  }
  
  type ('bel,'abv,'state) basic =
    state -> View.full -> 'state * (('bel,'abv) handlers_lout -> ('bel,'abv) handlers_lin)
  
  (**************************************************************)
  (* Alias for common layers in this architecture.
   *)
  
  type ('local,'hdr,'state,'abv1,'abv2,'abv3) t = 
    (('abv1,'abv2,'abv3) msg, ('local,'hdr,('abv1,'abv2,'abv3)msg) msg,'state) basic
  
  val hdr :
    (state -> View.full -> 'state) ->
    ('state -> View.full -> ('local,'hdr,('abv1,'abv2,'abv3)msg) full) ->
    (*Typedescr.t*)int option ->
    ('local,'hdr) optimize ->
    ('local,'hdr,'state,'abv1,'abv2,'abv3) t
  
  val hdr_noopt :
    (state -> View.full -> 'state) ->
    ('state -> View.full -> ('local,'hdr,('abv1,'abv2,'abv3)msg) full) ->
    ('local,'hdr,'state,'abv1,'abv2,'abv3) t
  
  (**************************************************************)
  (* These are strings used in lots of layers, so we share
   * them all here.
   *)
  val syncing : string
  val block : string
  val buffer : string
  val unknown_local : string
  val bad_header : string
  val bad_up_event : string
  val layer_fail : (View.full -> 'a -> unit) -> View.full -> 'a -> debug -> string -> 'b
  val layer_dump : debug -> (View.full -> 'a -> string array) -> View.full -> 'a -> unit
  val layer_dump_simp : debug -> View.full -> 'a -> unit
  (**************************************************************)
  (* Layer management.
   *
   * [OR]: This has been moved back here, away from the elink 
   * module. I think dynamic linking should be done by the caml
   * folk, not us. 
   *)
  type name = string
  
  val install : name -> ('a,'b,'c) basic -> unit
  val get : name -> ('a,'b,'c) basic
  
  (**************************************************************)
  
end

module Transport : sig
  (**************************************************************)
  (* TRANSPORT.MLI *)
  (* Author: Mark Hayden, 7/95 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* This is the type of object used to send messages.
   *)
  type 'msg t
  
  (* Construct and enable a new transport instance.
   *)
  val f :
    Alarm.t ->
    (Addr.id -> int) ->
    View.full ->
    Stack_id.t ->				(* stack id *)
    'msg Route.t ->			(* connection table *)
    (Conn.kind -> bool -> 'msg) -> (* message handler *)
    'msg t
  
  val f2 :
    Alarm.t ->
    (Addr.id -> int) ->
    View.full ->
    Stack_id.t ->				(* stack id *)
    'msg Route.t ->			(* connection table *)
    ('msg t -> ((Conn.kind -> bool -> 'msg) * 'a)) -> (* message handler *)
    'a
  	
  (**************************************************************)
  
  val disable	: 'msg t -> unit	(* disable the transport*)
  val send	: 'msg t -> rank -> 'msg (* send on the transport *)
  val cast	: 'msg t -> 'msg	(* cast on the transport *)
  val gossip	: 'msg t -> Addr.set option -> 'msg (* gossip on the transport *)
  
  (**************************************************************)
end

module Glue : sig
  (**************************************************************)
  (* GLUE.MLI *)
  (* Author: Mark Hayden, 10/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type glue = 
    | Imperative 
    | Functional
  
  type ('state,'a,'b) t
  
  val of_string : string -> glue
  
  val convert : glue -> ('bel,'abv,'state) Layer.basic -> ('state,'bel,'abv) t
  
  val compose : ('s1,'abv,'mid) t -> ('s2,'mid,'bel) t -> ('s1*'s2,'abv,'bel) t
  
  type ('state,'top,'bot) init = ('state,'top,'bot) t -> 
    'top ->
    'bot ->
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->
    View.full ->
    (Event.up -> unit) -> 
    (Event.dn -> unit)
  
  (*
  val init : ('top,'bot) init
  *)
  val init : ('state,'top,('a,'b,'c)Layer.msg) init
  
  (**************************************************************)
  
  module type S =
    sig
      type ('state,'a,'b) t
      val convert : ('a,'b,'state) Layer.basic -> ('state,'a,'b) t
      val revert  : ('state,'a,'b) t -> ('a,'b,'state) Layer.basic
      val wrap_msg : ('a -> 'b) -> ('b -> 'a) -> ('c, 'd, 'a) t -> ('c, 'd, 'b) t
      val compose : ('s1,'a,'b) t -> ('s2,'b,'c) t -> ('s1*'s2,'a,'c) t
      type ('state,'top,'bot) init = 
        ('state,'top,'bot) t -> 
        'top -> 'bot ->
        Alarm.t ->
        (Addr.id -> int) ->
        Layer.state ->
        View.full ->
        (Event.up -> unit) -> 
        (Event.dn -> unit)
  
      val init : ('state,'top,('a,'b,'c) Layer.msg) init
    end
  
  (**************************************************************)
  
  val inject_init : debug -> Sched.t -> (Event.up -> 'a -> unit) -> 'a -> unit
  
  (**************************************************************)
  
  module Functional : S with
    type ('state,'b,'a) t = 
      Layer.state -> 
      View.full -> 
      'state * (('state * ('a,'b) Event.dirm) -> 
                ('state * ('b,'a) Event.dirm Fqueue.t))
end

module Stacke : sig
  (**************************************************************)
  (* STACKE.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  
  val config_full : 
    Glue.glue ->				(* glue *)
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->			(* application *)
    View.full ->				(* view state *)
    (Event.up -> unit) ->			(* events out of top *)
    (Event.dn -> unit)			(* events into top *)
  
  (**************************************************************)
  
  val config :
    Glue.glue ->				(* glue *)
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->			(* application *)
    View.full ->				(* view state *)
    unit
  
  (**************************************************************)
end

module Arge : sig
  (**************************************************************)
  (* ARGE.MLI *)
  (* Author: Mark Hayden, 4/96 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type 'a t
  
  (* Get and set parameters.
   *)
  val get : 'a t -> 'a
  val set : 'a t -> 'a -> unit
  val set_string : 'a t -> string -> unit
  
  (* Check an option parameter to make sure it has been set.
   *)
  val check : debug -> 'a option t -> 'a
  
  (**************************************************************)
  val bool : (name -> bool -> 'a) -> 'a -> name -> string -> 'a t
  val int : (name -> int -> 'a) -> 'a -> name -> string -> 'a t
  val string : (name -> string -> 'a) -> 'a -> name -> string -> 'a t
  (**************************************************************)
  (**************************************************************)
  (* These are the parameter variables set by this module.
   *)
  
  val aggregate    : bool t		(* aggregate messages *)
  val alarm	 : string t		(* alarm to use *)
  val force_modes	 : bool t		(* force modes, no matter what *)
  val gossip_hosts : string list option t	(* where to find gossip servers *)
  val gossip_port  : port option t	(* where to find gossip server *)
  val port         : port option t	(* ensemble default port *)
  val group_name	 : string t		(* default group name *)
  val groupd       : bool t		(* use groupd server? *)
  val groupd_balance : bool t		(* load balance groupd servers? *)
  val groupd_hosts : string list option t (* where to find groupd servers *)
  val groupd_port  : port option t	(* TCP port to use for groupd *)
  val groupd_repeat : bool t      	(* try multiple times to reach groupd *)
  val protos       : bool t	        (* use protos server *)
  val protos_port  : port option t	(* TCP port to use for protos *)
  val protos_test  : bool t               (* used for testing protos *)
  val id           : string t		(* user id for application *)
  val key		 : string option t	(* security key to use *)
  val log          : bool t		(* use log server? *)
  val log_port     : port option t	(* TCP port to use for log *)
  val modes	 : Addr.id list t	(* default modes to use *)
  val deering_port : port option t	(* deering port *)
  val properties   : Property.id list t	(* default protocol properties *)
  val roots	 : bool t		(* output resource info? *)
  val glue         : Glue.glue t		(* selected layer glue. *)
  val pgp          : string option t	(* are we using pgp? *)
  val pgp_pass     : string option t	(* pass phrase for pgp *)
  val pollcount    : int t		(* number of failed polls before blocking *)
  val multiread    : bool t		(* do we read all data from sockets? *)
  val sched_step   : int t		(* number of events to schedule per step *)
  val host_ip      : string option t	(* hostname override to a specific IP address *)
  val udp_port     : port option t	(* port override for UDP communication *)
  val netsim_socks : bool t		(* allow socks with Netsim *)
  val debug_real   : bool t		(* use real time for debugging logs *)
  val short_names  : bool t		(* use short names for endpoints *)
  val sock_buf     : int t                (* size of kernel socket buffers *)
  val chunk_size   : int t                (* the size of memory chunks *) 
  val max_mem_size : int t                (* the amount of memory for user data *)
  
  (**************************************************************)
  val gc_compact  : int -> unit           (* Set GC compaction rate *)
  val gc_verb     : unit -> unit          (* Set GC verbosity *)
  (**************************************************************)
  
  val inet_of_string : 'a t -> string -> inet
  val inet_of_string_list : 'a t -> string list -> inet list
  
  (**************************************************************)
  
  (* Returns sorted list of default Ensemble command-line arguments.
   *)
  val args 	: unit -> (string * Arg.spec * string) list
  
  (* Takes application arguments and parses them along with
   * the Ensemble arguments.
   *)
  val parse	: (string * Arg.spec * string) list -> (string -> unit) -> string -> unit
  
  (* Can be used for capturing command-line problems.
   *)
  val badarg 	: string -> string -> unit
  
  (**************************************************************)
  
  val timestamp_check : string -> bool
  
  (**************************************************************)
  val arg_filter : (string array -> string array) -> unit
  (**************************************************************)
  
  val gossip_changed : bool ref           (* Did the gossip hosts list change *)
  val get_new_gossip : unit -> Hsys.inet array (* Return the new gossip hosts *)
  val set_new_gossip : Hsys.inet array -> unit (* set the new gossip hosts *)
  val set_servers : Hsys.inet list -> unit (* set servers in the cluster *)
  val get_servers : unit -> Hsys.inet list (* get servers in the cluster *)
end

module Mutil : sig
  (**************************************************************)
  (* MUTIL.MLI *)
  (* Author: Mark Hayden, 8/97 *)
  (* Designed with Roy Friedman *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  type endpt = Buf.t
  type group = Buf.t
  
  (**************************************************************)
  
  (* MEMBER_MSG: messages from a member to the membership service.
   * These messages are all prefixed with the Endpt.id and Group.id
   * of the member sending the message.
  
   * Join: request to join the group.  Replied with a View message.
  
   * Synced: this member is synchronized.  Is a reply to a Sync
   * message.  Will be replied with a View message.
  
   * Fail(endpt list): remove these members from the group.
   *) 
  type member_msg =
    | Join of ltime
    | Synced
    | Fail of endpt list
     
  (**************************************************************)
  
  (* COORD_MSG: messages from the service to a member.  These
   * messages are all prefixed with the Group.id of the group
   * for which these messages are being sent.
  
   * View(view,ltime): a new view is being installed.  The
   * view is a list of Endpt.id's.  A member who just sent a
   * Join message may not be included in the view, in which
   * case it should await the next View message.  The ltime is
   * the logical time of the view.  The first entry in the
   * view and the ltime uniquely identify the view.  The
   * ltime's a member sees grow monotonicly.
  
   * Sync: all members should "synchronize" (usually this means
   * waiting for messages to stabilize) and then reply with
   * a SyncOk message.
  
   * Failed: a member is being reported as having failed.
   * This is done because members may need to know about
   * failures in order to determine when they are
   * synchronized.
   *)
  type coord_msg =
    | View of ltime * primary * (endpt list)
    | Sync
    | Failed of endpt list
  
  (**************************************************************)
  
  (* Wrap a groupd client to check that it follows
   * the published state machine transitions correctly.
   *)
  val wrap :  
    ((member_msg -> unit) -> (coord_msg -> unit)) ->
    ((member_msg -> unit) -> (coord_msg -> unit))
  
  (**************************************************************)
  
  val string_of_endpt : endpt -> string
  
  (**************************************************************)
  
  val string_of_member_msg : member_msg -> string
  
  val string_of_coord_msg : coord_msg -> string
  
  (**************************************************************)
  val set_string_of_endpt : (endpt -> string) -> unit
  (**************************************************************)
end

module Manage : sig
  (**************************************************************)
  (* MANAGE.MLI *)
  (* Author: Mark Hayden, 11/96 *)
  (* Designed with Roy Friedman *)
  (**************************************************************)
  open Trans
  open Mutil
  (**************************************************************)
  
  (*
   * MANAGE.T: Type of a manager instance.
   *)
  type ('member,'group) t
  
  (*
   * CREATE: create a new manager instance within this process.
   * The view state gives information about this member,
   * including the name of the manager group.
   *)
  val create : Alarm.t -> View.full -> (('m,'g) t * View.full * Appl_intf.New.t)
  
  (*
   * PROXY: create a proxy for a manager in another process.
   *)
  val proxy : Alarm.t -> Hsys.socket -> ('m,'g) t
  
  (* 
   * JOIN: join a group through a manager.
   *)
  val join :
    ('m,'g) t -> group -> endpt -> ltime ->
    (coord_msg -> unit) -> (member_msg -> unit)
  
  (*
   * CONFIG: Run a protocol stack through a manager.
   *)
  val config : 
    ('m,'g) t ->				(* manager instance *)
    View.full ->				(* view state *)
    (View.full -> (Event.up -> unit) -> (Event.dn -> unit)) -> (* configured stack *)
    unit
  
  (**************************************************************)
  (**************************************************************)
  
  (* PROXY_SERVER: creates a TCP server on the given local TCP
   * port.  The instance must be a manager instance created
   * with the manager function.  
   *)
  val proxy_server : Alarm.t -> ('m,'g) t -> port -> unit
  
  val create_proxy_server : Alarm.t -> port -> View.full -> View.full * Appl_intf.New.t
  
  (**************************************************************)
  (**************************************************************)
  (* NOTE: The functions below only work on managers created
   * within this process (not those created by the "proxy"
   * function *)
  
  (* SET_PROPERTIES: Set the properties of a manager. This
   * installs a group announcement handler and specifies the
   * properties of the manager.  The properties of the manager
   * are used for remote filtering of announcements (not
   * currently implemented).  Announced groups cause the
   * handler to be executed at members who are not filtered
   * out.
   *)
  
  val set_properties : 
    ('m,'g) t -> 
    'm ->					(* member's state *)
    (Group.id -> 'g -> unit) ->		(* group announcement handler *)
    unit
  
  (* ANNOUNCE: Announce the creation of a new group.  Members
   * who have not heard of the new group before will have it
   * announced on their handler (if they have installed one).
   * The filter function is used to filter out members who
   * will not be in the group.  The group identifier and the
   * properties are passed to each of the members who are not
   * filtered out so that they can decide whether to join the
   * group.  Groups are persistent and will be announced to
   * new members as they join.  
   *)
  val announce : 
    ('m,'g) t ->
    Group.id ->				(* group identifier *)
    ('m -> bool) ->			(* member filter NOT IMPLEMENTED *)
    'g ->					(* group properties *)
    unit
  
  (* DESTROY: Destroy a group.  This causes all members in the
   * group to immediately leave the group.  That group will no
   * longer be announced to new members.  But if it is
   * announced again (or if we merge with another partition
   * that has announced the group), then it will continue to
   * be announced until another destroy operation is made.
   *)
  val destroy :				(* NOT IMPLEMENTED *)
    ('m,'g) t ->
    Group.id ->				(* group identifier *)
    unit
  
  (**************************************************************)
  (* These are tailored for the groupd.
   *)
  
  type t2 = 
      View.full -> 
      (View.full -> (Event.up -> unit) -> (Event.dn -> unit)) -> 
        unit
  
  val groupd_create : 
    Alarm.t -> View.full -> (t2 * View.full * Appl_intf.New.t)
  
  
  val groupd_proxy : 
    Alarm.t -> Hsys.socket -> t2
  
  (**************************************************************)
  
  
end

module Appl : sig
  (**************************************************************)
  (* APPL.MLI *)
  (* Author: Mark Hayden, 4/95 *)
  (**************************************************************)
  open Trans
  (**************************************************************)
  
  (* This process' alarm.  This should normally not be called
   * directly.
   *)
  val alarm : debug -> Alarm.t
  
  (* Get a list of addresses for this process, based on a set
   * of "modes."
   *)
  val addr :
    Addr.id list -> 
    Addr.set
  
  (* Create default view state information for singleton groups.
   *)
  val default_info :
    debug ->				(* application name *)
    View.full
  
  (* Take View.full and switch on all the security switches. 
   *)
  val set_secure : 
    View.full -> 
    Property.id list -> 
    View.full
  
  (* Create view state information for singleton groups, but
   * you can give more information than default_info.
   *)
  val full_info :
    debug ->				(* application name *)
    Endpt.id ->				(* endpoint *)
    bool ->				(* use groupd server? *)
    bool ->				(* use protos server? *)
    Proto.id ->				(* protocol stack to use *)
    (Addr.id list) ->			(* modes to use *)
    Security.key ->			(* key to use *)
    View.full
  
  
  (* Main loop of Ensemble.  Never returns.
   *)
  val main_loop : unit -> unit
  
  (* Execute main function if application has one of the
   * specified names.  Works for the various operating
   * systems supported by Ensemble.
   *)
  val exec :
    string list ->			(* application names *)
    (unit -> unit) ->			(* main function *)
    unit
  
  (* Configure a stack.  Supports normal/groupd/protos stacks.
   *)
  val config_new :
    Appl_intf.New.t ->			(* application *)
    View.full ->				(* view state *)
    unit
  
  (* Configure a stack.  Supports normal/groupd/protos stacks.
   * 
   * return the Application state. Currently used only for the 
   * ensemble daemon process. We shall see if this is useful in 
   * the future. 
   *)
  val config_new_hack :
    Appl_intf.New.t ->			(* application *)
    View.full ->				(* view state *)
    Layer.state
  
  (* Configure a stack.  Supports normal/groupd/protos stacks.
   *)
  val config_new_full :
    Layer.state ->			(* application state *)
    View.full ->				(* view state *)
    unit
  
  (* Request an asynchronous event for an application.
   *)
  val async :
    (Group.id * Endpt.id) ->		(* Id of application *)
    (unit -> unit)			(* request function *)
  
  (**************************************************************)
  
  val init_groupd : unit -> Manage.t2 (* for perf tests *)
  
  (* This starts a "thread" that can be used to monitor
   * various resources in the system.  It should only be
   * called once.
   *)
  val start_monitor : unit -> unit
  
  (**************************************************************)
  
  open Trans
  
  type cast_info = {
    mutable acct_recd    : seqno ;	  (* # delivered messages *)
    mutable acct_lost    : seqno ;	  (* # lost messages *)
    mutable acct_retrans : seqno ;          (* # retrans messages *)
    mutable acct_bad_ret : seqno ;	  (* # retrans messages not used *)
    mutable acct_sent    : seqno	          (* # retrans messages sent by *)
  }
  
  val cast_info : cast_info
  
  (**************************************************************)
end

module Reflect : sig
  (**************************************************************)
  (* REFLECT.MLI: server side of gossip transport *)
  (* Author: Mark Hayden, 8/95 *)
  (**************************************************************)
  open Trans
  
  val init : Alarm.t -> View.full -> port -> bool -> (View.full * Appl_intf.New.t)
  
end

module Protos : sig
  (**************************************************************)
  (* PROTOS.MLI *)
  (* Authors: Mark Hayden, Alexey Vaysburd 11/96 *)
  (* Cleanup by Ohad Rodeh 11/2001, removed direct dynamic linking *)
  (* support. Hopefully Caml will support it natively.*)
  (**************************************************************)
  open Trans
  open Appl_intf open New
  (**************************************************************)
  
  type id = int
  type 'a dncall_gen = ('a,'a) action
      
  type 'a upcall_gen = 
    | UInstall of View.full
    | UReceive of origin * cast_or_send * 'a
    | UHeartbeat of Time.t
    | UBlock
    | UExit
        
  type 'a message_gen =
    | Create of id * View.state * Time.t * (Addr.id list)
    | Upcall of id * 'a upcall_gen
    | Dncall of id * 'a dncall_gen
        
  type message = Iovecl.t message_gen
  type dncall = Iovecl.t dncall_gen
  type upcall = Iovecl.t upcall_gen
      
  val string_of_message : 'a message_gen -> string
  
  val string_of_dncall : 'a dncall_gen -> string
  
  val string_of_upcall : 'a upcall_gen -> string
  
  (**************************************************************)
  
  (* The type of a protos connection.
   *)
  type config = View.full -> Layer.state -> unit
  
  (**************************************************************)
  
  (* Generate a message marshaller.
   * marshal a message into an ML buffer, and an iovecl.
    *)
  val make_marsh :
    unit -> 
      (message -> Buf.t * Iovecl.t) *
      (Buf.t * Iovecl.t -> message)
  
  (* Handle a new client connection.
   *)
  val server :
    Alarm.t ->
    (Addr.id list -> Addr.set) ->
    (Appl_intf.New.t -> View.full -> unit) ->
    debug -> (message -> unit) ->
    ((message -> unit) * (unit -> unit) * unit)
  
  (* Create a client instance given message channels.
   *)
  val client :
    Alarm.t -> 
    debug -> (message -> unit) ->
    ((message -> unit) * (unit -> unit) * config)
  
  (**************************************************************)
end

module Hsyssupp : sig
  (**************************************************************)
  (* HSYSSUPP.MLI *)
  (* Author: Mark Hayden, 6/96 *)
  (* Rewrite for new IO and MM system: Ohad Rodeh, 12/2003 *)
  (**************************************************************)
  open Trans
  open Buf
  (**************************************************************)
  
  (* The send function is of the form: [hdr ofs len iovl].
   * The first header is composed of [ml_len iovl_len]
   *)
  type 'a conn =
      debug -> 
        (* We are assuming the sender may reuse the send buffer *)
        (Buf.t -> ofs -> len -> Iovecl.t -> unit) -> (* A send function *)
  	((Buf.t -> len -> Iovecl.t -> unit) (* A receive function *)
  	* (unit -> unit)    (* A disable function *)
  	* 'a)               (* An application state *)
  
  
  (* Turn a TCP socket into a send and recv function.
   *)
  
  val server : 
    debug -> 
    Alarm.t ->
    port ->
    unit conn ->
    unit
       
  val client : 
    debug -> 
    Alarm.t ->
    Hsys.socket ->
    'a conn ->
    'a
  
  
  (* 
   * [connect debug port hosts balance repeat]
   * try connecting through a port to one out of a list of hosts waiting
   * for TCP connections. the last two flags control whether to use
   * load-balancing, and if to repeat upon failure.
  *)
  val connect : debug -> port -> inet list -> bool -> bool -> Hsys.socket
end

module Timestamp : sig
  (**************************************************************)
  (* TIMESTAMP.MLI *)
  (* Author: Mark Hayden, 4/97 *)
  (**************************************************************)
  
  type t
  
  val register : Trans.debug -> t
  
  val add : t -> unit
  
  val print : unit -> unit
  
end

