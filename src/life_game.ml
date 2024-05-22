open Effect
open Effect.Deep
open Lib

type _ Effect.t += Display : int -> unit Effect.t
type _ Effect.t += Count : unit -> int array array Effect.t
type _ Effect.t += Make_next_array : int array array -> unit Effect.t
type _ Effect.t += Change : (int * int) -> unit Effect.t
type _ Effect.t += Step : unit -> unit Effect.t

let xsize = 10
let ysize = 10
let gen = 100

let int_to_color n = 
  match n with
  | 0 -> Some 15 (* 白 *)
  | 1 -> Some 70 (* 緑色 *)
  | _ -> None 

let rule now_array count_array next_array x y =
  match now_array.(y).(x) with
  | 0 -> (match count_array.(y).(x) with
          | 3 -> next_array.(y).(x) <- 1
          | _ -> ())
  | 1 -> (match count_array.(y).(x) with
          | 2 | 3 -> next_array.(y).(x) <- 1
          | _ -> next_array.(y).(x) <- 0)
  | _ -> ()

let run f = 
  let now_array = Array.make_matrix (ysize+2) (xsize+2) 0 in 
  let next_array = Array.make_matrix (ysize+2) (xsize+2) 0 in
  match_with f () {
    retc = (fun x -> x);
    exnc = (fun e -> raise e);
    effc = (fun  (type b) (eff: b t)-> 
      (match eff with
        | Display n -> 
          (Some (fun (k: (b,_) continuation) ->
            ignore (Unix.system "clear");
            let _ = print_string ("第" ^ (string_of_int n) ^ "世代\n") in 
            let rec f i j = 
              if i > ysize then ()
              else if j > xsize then (print_newline ();
                                      f (i+1) 1)
              else ((let color = int_to_color now_array.(i).(j) in
                      match color with
                      | Some x -> Cli.print_color_cell x
                      | None -> ());
                    f i (j+1))
            in f 1 1;
            continue k ()
          ))
        | Count () ->
          (Some (fun (k: (b,_) continuation) ->
            let count_array = Array.make_matrix (ysize+2) (xsize+2) 0 in
            let rec f i j k pre = 
            if i > ysize then ()
            else (
                  if j > xsize then f (i+1) 1 (-1) 0 
                  else (
                        if k > 1 then (
                                      count_array.(i).(j) <- pre;
                                      f i (j+1) (-1) 0
                                      )
                        else if k == 0 then(
                                            let count = now_array.(i).(j-1) + now_array.(i).(j+1) in 
                                            f i j (k+1) (count+pre)
                                            )
                        else (
                              let count = now_array.(i+k).(j-1) + now_array.(i+k).(j) + now_array.(i+k).(j+1) in 
                              f i j (k+1) (count+pre)
                              )
                        )
                  ) 
            in f 1 1 (-1) 0;
            continue k count_array
          ))
        | Make_next_array (count_array) ->
          (Some (fun (k: (b,_) continuation) ->
            let rec f i j = 
              if i > ysize then ()
              else if j > xsize then (f (i+1) 1)
              else (rule now_array count_array next_array j i;
                    f i (j+1))
            in f 1 1;
            continue k ()
          ))
        | Change (x,y) ->
          (Some (fun (k: (b,_) continuation) ->
            (match now_array.(y).(x) with
            | 0 -> now_array.(y).(x) <- 1
            | 1 -> now_array.(y).(x) <- 0
            | _ -> ()
            );
            continue k ()
          ))
        | Step () ->
          (Some (fun (k: (b,_) continuation) ->
            let rec f i = 
              if i > ysize then ()
              else (Array.blit next_array.(i) 1 now_array.(i) 1 xsize;
                    f (i+1))
            in f 1;
            continue k ()
          ))
        | _ -> None)
    )
  }

let main () =
  let _ = perform (Change (1,1)) in 
  let _ = perform (Change (2,2)) in 
  let _ = perform (Change (4,3)) in 
  let _ = perform (Change (1,4)) in 
  let _ = perform (Change (2,4)) in 
  let rec loop n = 
    if n < gen then (let _ = perform (Display n) in 
                     let count = perform (Count ()) in 
                     let _ = perform (Make_next_array count) in 
                     let _ = perform (Step ()) in 
                     Unix.sleepf 0.1;
                     (loop (n+1))
                    )
    else perform (Display n) 
  in loop 0

let _ = run main 