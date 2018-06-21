#!/usr/bin/env hy

(import
  [os [environ]]
  [sys [argv stderr path exit]]
  [random [Random]]
  [pprint [pprint]])

(path.append "drillbit")

(import
  [autotracker.utils [track-builder add-message initial-hash extract-hash make-rng]]
  [autotracker.compose [make-notes-progression]]
  [generators [lookup]])

(require hy.contrib.loop)

(defn main [argv]
  (if (or
        (< (len argv) 3)
        (not (in (get argv 2) lookup)))
    (usage argv)
    (let [[bpm (int (get argv 1))]
          [hash-song (initial-hash (.get environ "HASH"))]

          [row-count 128]

          [[it sampler pattern-gen] (track-builder "Algorave loop" bpm row-count)]
          [fname (+ "loop-" hash-song ".it")]

          [progression (make-notes-progression (make-rng hash-song "notes"))]
          
          ;[[note-sets rootnote pattern] (list-comp (get progression n) [n [:note-sets :rootnote :pattern]])]
          [notes (if (.has_key environ "NOTES")
                   (list-comp (int n) [n (.split (.get environ "NOTES") " ")])
                   (.sample (make-rng hash-song "notes") [0 2 4 5 7 9 11] 4))]
          [rootnote 60]
          [pattern [1 1 1 1]]
          
          [sections (len pattern)]
          ;[_ (print sections note-sets pattern)]
          ; TODO: write all params & inputs to a file

          [generator-names (slice argv 2)]
          [generators (list-comp (get lookup generator-name) [generator-name generator-names])]
          [sample-sets (list-comp
                         (let [[generator (get generators g)]] (.make-sample-set generator (make-rng hash-song "samples" g generator.__file__) it sampler))
                         [g (range (len generators))])]

          [settings (list-comp
                      (let [[generator (get generators g)]] (.make-pattern-settings generator (make-rng hash-song "pattern" g generator.__file__) it :sample-set (get sample-sets g) :rootnote rootnote :notes notes))
                      [g (range (len generators))])]]

      (for [p (range sections)]
        (loop [[channel 0] [g 0]]
          (let [[generator (get generators g)]
                [rnd-beats (make-rng hash-song "pattern" g generator.__file__ p)]]
            (.make-pattern generator rnd-beats it pattern-gen (get settings g) (get sample-sets g) p channel row-count)
            ; alternate left and right channels
            (for [chnpan (range generator.channels)]
              (setv (get it.chnpan (+ channel chnpan)) (get [0 63] (% g 2))))
            (when (< g (dec (len generators)))
              (recur (+ generator.channels channel) (inc g))))))
      
      (print fname)
      (it.save fname)
      (print (.join " " argv) :file (file (+ fname ".txt") "w")))))

(defn usage [argv]
  (print "Usage:" (get argv 0) "BPM GENERATOR-1 [GENERATOR-2...]")
  (print "Environment variables:\n")
  (print "Generators:")
  (for [k lookup]
    (print "\t" k))
  (exit))

(if (= __name__ "__main__")
  (main argv))