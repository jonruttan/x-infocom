; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/quetzal.x -- saving and restoring, in the Quetzal format
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Quetzal (Standard 1.4) is the save format every current interpreter
; shares: an IFF FORM of type IFZS holding
;
;   IFhd  release, serial, checksum, and the pc of the save instruction's
;         branch or store data
;   CMem  dynamic memory XORed with the story's own, runs of zeros written
;         as a zero and a count (UMem, uncompressed, is read too)
;   Stks  the frames, oldest first: return pc, flags (local count; bit 4
;         when the result is discarded), result variable, arguments
;         supplied as a bit mask, evaluation stack size, the locals, then
;         that stack
;
; so a save from this machine restores in dfrotz and one from dfrotz
; restores here.  A restore puts the machine where the save left it and
; then finishes the save instruction as a success: before version 4 by
; taking its branch, after it by storing 2.

(provide infocom/quetzal zm-save zm-restore zm-save-dir!)

(def %zm-save-dir "")
(def zm-save-dir! (fn (_ dir) (set! %zm-save-dir dir)))

; --- building bytes: a reversed list, written out at the end ---------------

(def %qz-word (fn (_ w acc) (pair (zm& w 255) (pair (zm& (zm>> w 8) 255) acc))))
(def %qz-long (fn (_ n acc) (%qz-word (zm& n 65535) (%qz-word (zm& (zm>> n 16) 65535) acc))))
(def %qz-three
  (fn (_ n acc)
    (pair (zm& n 255) (pair (zm& (zm>> n 8) 255) (pair (zm& (zm>> n 16) 255) acc)))))
(def %qz-text
  (fn (_ s acc)
    (def n (%zm-byte-len s))
    (def go
      (fn (self i acc)
        (if (zm< i n) (self (zm+ i 1) (pair (%zm-char->int (%zm-byte-ref s i)) acc)) acc)))
    (go 0 acc)))

; A chunk: id, length, the data (given in order), a pad byte to even length.
(def %qz-chunk
  (fn (_ id data acc)
    (def n (%zm-length data))
    (def body (%zm-rev-onto data (%qz-long n (%qz-text id acc))))
    (if (zm= (zm& n 1) 0) body (pair 0 body))))

(def %qz-ifhd
  (fn (_ pc)
    (def serial
      (fn (self i acc) (if (zm< i 6) (self (zm+ i 1) (pair (zm-rb (zm+ 18 i)) acc)) acc)))
    (%zm-rev (%qz-three pc (%qz-word (zm-rw 28) (serial 0 (%qz-word (zm-rw 2) ())))))))

; Dynamic memory against the story's: each byte XORed, zero runs counted.
(def %qz-cmem
  (fn (_)
    (def end zm-hdr-static)
    (def zeros
      (fn (self n acc)
        (if (zm< 256 n)
          (self (zm- n 256) (pair 255 (pair 0 acc)))
          (pair (zm- n 1) (pair 0 acc)))))
    (def go
      (fn (self a run acc)
        (if (zm< a end)
          (do
            (def x (zm^ (zm-rb a) (%zm-orig-rb a)))
            (if (zm= x 0)
              (self (zm+ a 1) (zm+ run 1) acc)
              (self (zm+ a 1) 0 (pair x (if (zm= run 0) acc (zeros run acc))))))
          (%zm-rev acc))))
    (go 0 0 ())))

; The routines on the stack, oldest first, each as
; (return-pc store nlocals locals argc base top).  The oldest is the dummy
; frame under the first routine: no return, no result to discard, as
; dfrotz writes it (it refuses one marked discarding).
(def %qz-routines
  (fn (_)
    (def go
      (fn (self frames locals n argc base top acc)
        (if (null? frames)
          (pair (list 0 0 n locals argc base top) acc)
          (do
            (def f (first frames))
            (def c (rest (rest f)))
            (self (rest frames) (first c) (first (rest (rest (rest c))))
              (first (rest (rest c))) (first (rest c)) base
              (pair (list (first f) (first (rest f)) n locals argc base top) acc))))))
    (go %zm-frames %zm-locals %zm-nlocals zm-argc %zm-base %zm-sp ())))

(def %qz-stks
  (fn (_)
    (def frame
      (fn (_ r acc)
        (def store (first (rest r)))
        (def n (first (rest (rest r))))
        (def locals (first (rest (rest (rest r)))))
        (def argc (first (rest (rest (rest (rest r))))))
        (def base (first (rest (rest (rest (rest (rest r)))))))
        (def top (first (rest (rest (rest (rest (rest (rest r))))))))
        (def a1 (%qz-three (first r) acc))
        (def a2 (pair (zm| n (if (zm< store 0) 16 0)) a1))
        (def a3 (pair (if (zm< store 0) 0 store) a2))
        (def a4 (pair (zm- (zm<< 1 (if (zm< 7 argc) 7 argc)) 1) a3))
        (def a5 (%qz-word (zm- top base) a4))
        (def ls
          (fn (self i acc) (if (zm< n i) acc (self (zm+ i 1) (%qz-word (%zm-obj-ref locals i) acc)))))
        (def ss
          (fn (self i acc) (if (zm< top i) acc (self (zm+ i 1) (%qz-word (%zm-obj-ref %zm-stack i) acc)))))
        (ss (zm+ base 1) (ls 1 a5))))
    (def go (fn (self rs acc) (if (null? rs) (%zm-rev acc) (self (rest rs) (frame (first rs) acc)))))
    (go (%qz-routines) ())))

; --- files -------------------------------------------------------------------

(def %qz-codes->str
  (fn (_ cs)
    (if (null? cs) ""
      (%zm-cvt (List map (fn (_ c) ((prim-ref (lit int) (lit ->char)) c)) cs) %zm-string-type))))

(def %zm-story-name "story")
(def %qz-default ())

; The file to use: asked for, as dfrotz asks, offering the last name given
; (the story's name in .qzl at first); a relative name is under the save
; directory.
(def %qz-ask-file
  (fn (_)
    (def dflt (if (null? %qz-default) (Str8 append %zm-story-name ".qzl") %qz-default))
    (zm-out-ascii (Str8 append "Please enter a filename [" (Str8 append dflt "]: ")))
    (def line (zm-read-raw-line))
    (if (null? line) ()
      (do
        (def name (if (null? (rest line)) dflt (%qz-codes->str (rest line))))
        (set! %qz-default name)
        (if (if (zm< 0 (%zm-byte-len name)) (zm= (%zm-char->int (%zm-byte-ref name 0)) 47) #f)
          name
          (if (zm= (%zm-byte-len %zm-save-dir) 0) name
            (Str8 append %zm-save-dir (Str8 append "/" name))))))))

(def %qz-write-file
  (fn (_ path bytes)
    (def n (%zm-length bytes))
    (def buf (%zm-str-make (zm+ n 1)))
    (def p (%zm-str->ptr buf))
    (def put (fn (self bs i) (if (null? bs) () (do (%zm-pset! p i (first bs) 1) (self (rest bs) (zm+ i 1))))))
    (put bytes 0)
    (def fd (File open path (list (lit wronly) (lit creat) (lit trunc)) 420))
    (if (zm< fd 0) #f
      (do
        (def w (zm-file-write fd buf n))
        (File close fd)
        (zm= w n)))))

; save: pc is the address of the save instruction's branch or store data.
(def zm-save
  (fn (_ pc)
    (def path (%qz-ask-file))
    (if (null? path) #f
      (do
        ; everything after the FORM length, reversed
        (def body
          (%qz-chunk "Stks" (%qz-stks)
            (%qz-chunk "CMem" (%qz-cmem)
              (%qz-chunk "IFhd" (%qz-ifhd pc) (%qz-text "IFZS" ())))))
        (def head (%qz-long (%zm-length body) (%qz-text "FORM" ())))
        (%qz-write-file path (%zm-rev (List append body head)))))))

; --- restoring ---------------------------------------------------------------

(def %qz-buf ())
(def %qz-ptr ())
(def %qz-size 0)
(def %qz-rb (fn (_ a) (zm& (%zm-pref %qz-ptr a 1) 255)))
(def %qz-rw (fn (_ a) (zm| (zm<< (%qz-rb a) 8) (%qz-rb (zm+ a 1)))))
(def %qz-rl (fn (_ a) (zm| (zm<< (%qz-rw a) 16) (%qz-rw (zm+ a 2)))))
(def %qz-r3 (fn (_ a) (zm| (zm<< (%qz-rb a) 16) (%qz-rw (zm+ a 1)))))
(def %qz-id? (fn (_ a s) (zm= (%qz-rl a) (%qz-rl-of s))))
(def %qz-rl-of
  (fn (_ s)
    (def c (fn (_ i) (%zm-char->int (%zm-byte-ref s i))))
    (zm| (zm<< (c 0) 24) (zm| (zm<< (c 1) 16) (zm| (zm<< (c 2) 8) (c 3))))))

(def %qz-load
  (fn (_ path)
    (if (File exists? path)
      (do
        (set! %qz-size (zm-file-size path))
        (set! %qz-buf (zm-file-read-all path))
        (set! %qz-ptr (%zm-str->ptr %qz-buf))
        #t)
      #f)))

; The chunks after the FORM header: an alist of id-number to (start . length).
(def %qz-chunks
  (fn (_)
    (def end (zm+ 8 (%qz-rl 4)))
    (def go
      (fn (self a acc)
        (if (zm< (zm+ a 7) end)
          (do
            (def len (%qz-rl (zm+ a 4)))
            (self (zm+ (zm+ a 8) (zm+ len (zm& len 1)))
              (pair (pair (%qz-rl a) (pair (zm+ a 8) len)) acc)))
          acc)))
    (go 12 ())))

(def %qz-find (fn (_ chunks s) (%zm-assq-int (%qz-rl-of s) chunks)))
(def %zm-assq-int
  (fn (self k al)
    (if (null? al) () (if (zm= (first (first al)) k) (rest (first al)) (self k (rest al))))))

; Is IFhd this story's?  release, serial and checksum must all agree.
(def %qz-ours?
  (fn (_ at)
    (def serial
      (fn (self i) (if (zm< i 6) (if (zm= (%qz-rb (zm+ (zm+ at 2) i)) (zm-rb (zm+ 18 i))) (self (zm+ i 1)) #f) #t)))
    (if (zm= (%qz-rw at) (zm-rw 2))
      (if (serial 0) (zm= (%qz-rw (zm+ at 8)) (zm-rw 28)) #f)
      #f)))

; Dynamic memory from CMem (XOR-RLE) or UMem.
(def %qz-memory!
  (fn (_ chunk compressed?)
    (def keep (zm& (zm-rb 17) 3))
    (def start (first chunk))
    (def end (zm+ start (rest chunk)))
    (def copy
      (fn (self a)
        (if (zm< a zm-hdr-static) (do (zm-wb! a (%zm-orig-rb a)) (self (zm+ a 1))))))
    (def go
      (fn (self i a)
        (if (if (zm< i end) (zm< a zm-hdr-static) #f)
          (do
            (def b (%qz-rb i))
            (if compressed?
              (if (zm= b 0)
                (self (zm+ i 2) (zm+ a (zm+ (%qz-rb (zm+ i 1)) 1)))
                (do (zm-wb! a (zm^ (%zm-orig-rb a) b)) (self (zm+ i 1) (zm+ a 1))))
              (do (zm-wb! a b) (self (zm+ i 1) (zm+ a 1))))))))
    (copy 0)
    (go start 0)
    (%zm-header-set!)
    (zm-wb! 17 (zm| (zm& (zm-rb 17) 252) keep))))

; The machine's stack and frames from Stks.
(def %qz-stack!
  (fn (_ chunk)
    (def end (zm+ (first chunk) (rest chunk)))
    (zm-cpu-reset!)
    (def argc-of (fn (self m k) (if (zm= (zm& m 1) 0) k (self (zm>> m 1) (zm+ k 1)))))
    (def go
      (fn (self a first?)
        (if (zm< a end)
          (do
            (def ret (%qz-r3 a))
            (def flags (%qz-rb (zm+ a 3)))
            (def var (%qz-rb (zm+ a 4)))
            (def args (%qz-rb (zm+ a 5)))
            (def words (%qz-rw (zm+ a 6)))
            (def n (zm& flags 15))
            (if first? ()
              (set! %zm-frames
                (pair (list ret (if (zm= (zm& flags 16) 0) var -1)
                        %zm-locals %zm-base zm-argc %zm-nlocals)
                  %zm-frames)))
            (def locals (%zm-new-locals))
            (def ls
              (fn (self i)
                (if (zm< n i) ()
                  (do (%zm-obj-set! locals i (%qz-rw (zm+ (zm+ a 6) (zm<< i 1)))) (self (zm+ i 1))))))
            (ls 1)
            (set! %zm-locals locals)
            (set! %zm-nlocals n)
            (set! zm-argc (argc-of args 0))
            (set! %zm-base %zm-sp)
            (def s0 (zm+ (zm+ a 8) (zm<< n 1)))
            (def ss
              (fn (self k)
                (if (zm< k words) (do (zm-push (%qz-rw (zm+ s0 (zm<< k 1)))) (self (zm+ k 1))))))
            (ss 0)
            (self (zm+ s0 (zm<< words 1)) #f)))))
    (go (first chunk) #t)))

; restore: answers the pc to go on from, or () when it fails, leaving the
; machine as it was.
(def zm-restore
  (fn (_)
    (def path (%qz-ask-file))
    (if (if (null? path) #t (not (%qz-load path))) ()
      (if (if (zm< %qz-size 12) #t (not (if (%qz-id? 0 "FORM") (%qz-id? 8 "IFZS") #f))) ()
        (do
          (def cs (%qz-chunks))
          (def hd (%qz-find cs "IFhd"))
          (def cm (%qz-find cs "CMem"))
          (def um (%qz-find cs "UMem"))
          (def st (%qz-find cs "Stks"))
          (if (if (null? hd) #t (if (null? st) #t (if (null? cm) (null? um) #f))) ()
            (if (not (%qz-ours? (first hd))) ()
              (do
                (def pc (%qz-r3 (zm+ (first hd) 10)))
                (if (null? cm) (%qz-memory! um #f) (%qz-memory! cm #t))
                (%qz-stack! st)
                (if (zm< zm-version 4)
                  (do
                    (def b (%zm-branch-at pc))
                    (%zm-br #t (first b) (rest b)))
                  (do (zm-var-set! (zm-rb pc) 2) (zm+ pc 1)))))))))))
