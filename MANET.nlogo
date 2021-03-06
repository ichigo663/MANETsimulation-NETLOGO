;; Author : Antonio Cardace
;; ID number : 0000738443
;; E-mail : antonio.cardace2@studio.unibo.it



;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Breeds definitions ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [nodes node]
breed [halos halo]
breed [ empty-set ]
undirected-link-breed [halolinks halolink] ;; this is just for the halo
undirected-link-breed [connections connection]

;;;;;;;;;;;;;;;;;;;;;;;
;;; Global variables ;;
;;;;;;;;;;;;;;;;;;;;;;;

globals [
   giant-component-edges-number
   giant-component-nodes-number
   giant-component ;; this is a list containing the nodes belonging to the giant component
   bridges
   ]

;;;;;;;;;;;;;;;;;;;;;;;
;;; Local variables ;;;
;;;;;;;;;;;;;;;;;;;;;;;

;;nodes local vars
nodes-own [ node-radius node-max-degree node-degree
  connected-nodes ;; the nodes to which this node is connected
  node-with-max-degree ;; the node with the maximum degree among the ones connected with this one
  local-component-nodes-number
  local-component  ;; a list containing the nodes of the component to which this node belongs
  visited          ;; useful for the DFS
  node-speed ]

;; to be used for bridge-detection
connections-own [ active bridge counted ]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Setup the environment
to setup
  clear-all
  set-default-shape turtles "default"
  set-default-shape halos "thin ring"
  create-nodes nodes-number
  ;setting global variables
  set giant-component-nodes-number 0
  set giant-component empty-set
  set bridges 0
  ask nodes [ ;; make the turtle initial position random to spread them out on the torus
    setxy random-xcor random-ycor
    ifelse ( all-different = true ) [ ;; if all-different is set every node has got different speed and max-degree
      set node-max-degree ( (random max-degree) + 1 )
      set node-speed ( (random node-velocity ) + 1 ) / 100 * max-pxcor * 2
    ]
    [
      set node-max-degree max-degree
      set node-speed node-velocity / 100 * max-pxcor * 2
    ]
    set node-radius radius / 100 * max-pxcor * 2
    make-halo node-radius
    ;setting local variables
    set connected-nodes []
    set local-component []
    set node-degree 0
    set local-component-nodes-number 0
    set visited false
  ]
  reset-ticks
end


;; this has been taken from a model included in netlogo
to make-halo [ halo-radius ]  ;; node procedure
  hatch-halos 1
  [ set size halo-radius + 4 ;; the + 4 it's just for visualization reasons
    set color lput 64 extract-rgb color
    __set-line-thickness 0.3
    ;; We create an invisible undirected link from the node
    ;; to the halo.  Using tie means that whenever the
    ;; node moves, the halo moves with it.
    create-halolink-with myself
    [ tie
      hide-link ] ]
end

;;;;;;;;;;;;;;;;;;;;;;
;;; Main Procedure ;;;
;;;;;;;;;;;;;;;;;;;;;;

;; Move every node according to their speed
;; if stop-sim? is true it runs for sim-length and then stops
to move [ stop-sim? rep-number ]
  ask nodes[
    rt random 360
    fd node-speed
  ]

  ;;these 3 instructions are broken in 3 different blocks for concurrency reasons
  ;;doing as below the nodes execute every instruction as in "parallel"
  ask nodes [ disconnect-not-in-radius ]
  ask nodes [ set-connected-nodes ]
  ask nodes [ connect-to-neighbors ]
  tick

  ;; this block of instructions is for exporting the plots data into csv files
  if ( stop-sim? = true ) and ( ticks >= run-length )[
    if export-plots = true [
      let dir "plots/"
      export-plot "Growth of connected component" ( word dir "Connectivity_" strategy "_" nodes-number "_" radius "_" max-degree "_" node-velocity "_" rep-number ".csv" )
      export-plot "Edge Density" ( word dir "Edge density_" strategy "_" nodes-number "_" radius "_" max-degree "_" node-velocity "_" rep-number ".csv" )
      export-plot "Bridges (%) in giant-component" ( word dir "Bridges_" strategy "_" nodes-number "_" radius "_" max-degree "_" node-velocity "_" rep-number ".csv" )
      export-plot "Degree distribution" ( word dir "Degree distribution_" strategy "_" nodes-number "_" radius "_" max-degree "_" node-velocity "_" rep-number ".csv" )
    ]

    stop
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Auxiliary Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to increase-degree
  set node-degree node-degree + 1
end


to decrease-degree
  set node-degree node-degree - 1
end

;;link the node with node in its radius
to connect-to-neighbors
  connect other nodes in-radius node-radius ;; connect the node prior to some replacement strategy
end

;; disconnect all the nodes which are not in the node's radius anymore
to disconnect-not-in-radius
  let nodes-in-radius other nodes in-radius node-radius
  if ( is-agentset? connected-nodes ) [
    ask connected-nodes [
      if ( member? self nodes-in-radius = false and link-neighbor? myself = true )[
        ask connection-with myself [ kill-connection ]
        decrease-degree
      ]
    ]
  ]
end

;; update the set of connected nodes
to set-connected-nodes
  set connected-nodes other nodes in-radius node-radius
end

;;this function can work both with agentsets or agents
to connect [ to-node ]
  let node-list []

  ifelse ( is-node? to-node = true )[
    set node-list lput to-node node-list
  ]
  [
    set node-list to-node
  ]

  foreach sort node-list [
    if ( link-neighbor? ? = false ) [
      ifelse ( node-degree < node-max-degree and ( [node-degree] of ? ) < ( [node-max-degree] of ? ) ) [
        increase-degree
        ask ? [ increase-degree ]
        create-connection-with ? [ set active true ]
      ][
        replacement-strategy ?
      ]
   ]
 ]
end

;;gets called by connections only, decreases the node's degree and kill the link
to kill-connection
  ask other-end [ decrease-degree ]
  die
end

;; computes all the reachable nodes by root-node and puts them in an agentset
;; if giant-computation? is set then this has been called from "get-giant-component"
to get-component [root-node giant-computation?]
  if self = root-node [
    set local-component-nodes-number 1
    set local-component []
    set local-component fput self local-component

    if giant-computation? = false [
      ask nodes [ set visited false ]
    ]
    set visited true
  ]

  ;;DFS
  ask my-connections with [ active = true ] [
    ask other-end [
      if visited = false [
        set visited true
        ask root-node [
          set local-component fput myself local-component
          set local-component-nodes-number local-component-nodes-number + 1
        ]
     get-component root-node giant-computation?
     ]
    ]
  ]
end

;; sets the current context as the biggest component of the network
to get-giant-component
  set giant-component-nodes-number 1
  let temp-giant-component one-of nodes
  set giant-component []
  set giant-component-edges-number 0

  ;;set all nodes as not visited
  ask nodes [ set visited false ]
  ask connections [ set counted false ]

  ;;ask all the nodes to compute their local component and add them to a list
  foreach sort nodes [
    if [visited] of ? = false [
     ask ? [ get-component self true ]
     ask ? [ set giant-component fput local-component giant-component ]
    ]
  ]

  set giant-component remove-duplicates giant-component

  ;; count the number of nodes of each component
  foreach giant-component [
    if is-list? ? = true [
      if length ? > giant-component-nodes-number [
        set giant-component-nodes-number length ?
        set temp-giant-component ?
      ]
    ]
  ]
  set giant-component temp-giant-component
  ;;compute the number of edges in the giant component
  if is-list? giant-component = true [
    foreach giant-component[
      foreach sort ( [my-connections] of ? ) [
        ask ? [
          if not counted [
            set counted true
            set giant-component-edges-number giant-component-edges-number + 1
          ]
        ]
      ]
    ]
  ]
end

;; count the bridges in the biggest component of the network
to count-bridges
  ask connections [ set bridge false ]
  set bridges 0

  if is-list? giant-component = true [
    ;;foreach node in the giant-component
    foreach giant-component [
      let current-node ?
      foreach sort [my-connections] of ?  [
        ask current-node [
          if is-bridge? ? [
            ask ? [ set bridge true ]
          ]
        ]
      ]
    ]

    set bridges count connections with [bridge = true]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Strategies Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; wrapper function for the replacement strategy
;; this way the strategy can be changed at runtime as well
to replacement-strategy [ node-to-connect ]
  if strategy = "Random-kill" [
    random-kill node-to-connect
  ]
  if strategy = "Max-degree-kill" [
    max-degree-kill node-to-connect
  ]
  if strategy = "No-bridge-kill (random)" [
    no-bridge-kill node-to-connect 0
  ]
  if strategy = "No-bridge-kill (max-degree)" [
    no-bridge-kill node-to-connect 1
  ]
  if strategy = "No-bridge-kill (most-distant)" [
    no-bridge-kill node-to-connect 2
  ]
  if strategy = "No-bridge-kill" [
   no-bridge-kill node-to-connect 3
  ]
  if strategy = "Most-distant-kill" [
    most-distant-kill node-to-connect
  ]
  if strategy = "Most-distant-no-bridge-kill" [
    most-distant-no-bridge-kill node-to-connect
  ]
  if strategy = "Max-degree-no-bridge-kill" [
    max-degree-no-bridge-kill node-to-connect
  ]
end

;;randomly kill a connection
to random-kill [ node-to-connect ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    ask one-of my-connections [ kill-connection ]
    ask node-to-connect [ ask one-of my-connections [ kill-connection ] ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      ask one-of my-connections [ kill-connection ]
      ask node-to-connect [ increase-degree ]
    ]
    [
      ask node-to-connect [ ask one-of my-connections [ kill-connection ] ]
      increase-degree
    ]
  ]
  create-connection-with node-to-connect [ set active true ]
end

;;this strategy kills the connection with the node having the maximum degree
to max-degree-kill [ node-to-connect ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    find-node-with-max-degree
    ask link-with node-with-max-degree [ kill-connection ]
    ask node-to-connect [
      find-node-with-max-degree
      ask link-with node-with-max-degree [ kill-connection ]
    ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      find-node-with-max-degree
      ask link-with node-with-max-degree [ kill-connection ]
      ask node-to-connect [ increase-degree ]
    ]
    [
      ask node-to-connect [
        find-node-with-max-degree
        ask link-with node-with-max-degree [ kill-connection ]
      ]
      increase-degree
    ]
  ]
  create-connection-with node-to-connect [ set active true ]
end

;;auxiliary procedure for "max-degree-kill"
to find-node-with-max-degree
  ;; determining which is the node with the maximum degree
  set node-with-max-degree first sort-by [ [node-degree] of ?1 > [node-degree] of ?2 ] connection-neighbors
end

;;this strategy kills a random connection as long as it is not a bridge
;;otherwise use "other?" strategy to decide how and whether to remove a connection
;;if "other?" = 3 -> if no-bridge connection is found then don't remove any existing connection
to no-bridge-kill [ node-to-connect other? ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    if is-no-bridge-present? = true and [is-no-bridge-present?] of node-to-connect = true [
      kill-no-bridge other?
      ask node-to-connect [ kill-no-bridge other? ]
      create-connection-with node-to-connect [ set active true ]
    ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      if is-no-bridge-present? = true [
        kill-no-bridge other?
        ask node-to-connect [ increase-degree ]
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
    [
      if [is-no-bridge-present?] of node-to-connect = true [
        ask node-to-connect [ kill-no-bridge other? ]
        increase-degree
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
  ]
end

;;kills a non-bridge connection (auxiliary procedure for random-no-bridge-kill)
to kill-no-bridge [ other? ]
  let flag false
  foreach shuffle sort my-connections [
     if is-bridge? ? = false and flag = false [
       set flag true
       ask ? [ kill-connection ]
     ]
    ]
  if flag = false[
    ;;according to the value of other? takes a decision in case it doesnt find any node no-bridge connection to kill
    ;; other? = 0 -> kill random node
    ;; other? = 1 -> kill the connection having the node with the maximum degree
    ;; other? = 2 -> kill the connection of the most distant node
    if other? = 0 [
      ask one-of my-connections [ kill-connection ]
    ]
    if other? = 1 [
      find-node-with-max-degree
      ask link-with node-with-max-degree [ kill-connection ]
    ]
    if other? = 2 [
      find-kill-most-distant
    ]
  ]
end

;;this strategy kills the connection with the most distant node
to most-distant-kill [ node-to-connect ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    find-kill-most-distant
    ask node-to-connect [ find-kill-most-distant ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      find-kill-most-distant
      ask node-to-connect [ increase-degree ]
    ]
    [
      ask node-to-connect [ find-kill-most-distant ]
      increase-degree
    ]
  ]
  create-connection-with node-to-connect [ set active true ]
end

;;auxiliary procedure for "most-distant-kill"
to find-kill-most-distant
  let max-distance -1
  let conn-to-kill connection-with first sort-by [ distance ?1 > distance ?2 ] connection-neighbors ;;set conn-to-kill as the connection with the most distant node
  ask conn-to-kill [ kill-connection ]
end

;;this strategy kills a no-bridge connection with the most distant node
;;if none are found doesn't establish the connection
to most-distant-no-bridge-kill [ node-to-connect ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    if is-no-bridge-present? = true and [is-no-bridge-present?] of node-to-connect = true [
      kill-no-bridge-most-distant
      ask node-to-connect [ kill-no-bridge-most-distant ]
      create-connection-with node-to-connect [ set active true ]
    ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      if is-no-bridge-present? = true [
        kill-no-bridge-most-distant
        ask node-to-connect [ increase-degree ]
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
    [
      if [is-no-bridge-present?] of node-to-connect = true [
        ask node-to-connect [ kill-no-bridge-most-distant ]
        increase-degree
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
  ]
end

;;auxiliary procedure for "most-distant-no-bridge-kill"
to kill-no-bridge-most-distant
  let set-distant-nodes sort-by [ distance ?1 > distance ?2 ] connection-neighbors ;;set of nodes ordered by decreasing distance
  let conn-to-kill connection-with first set-distant-nodes
  foreach set-distant-nodes[
   if is-bridge? ? = false [
     set conn-to-kill connection-with ?
   ]
  ]
  ask conn-to-kill [ kill-connection ]
end

;;this strategy kills a no-bridge connection with the node
;;which has maximum degree, if all the connections are bridges
;;it doesn't establish a new connection
to max-degree-no-bridge-kill [ node-to-connect ]
  ifelse ( node-degree = node-max-degree and ( [node-degree] of node-to-connect ) = ( [node-max-degree] of node-to-connect ) ) [
    if is-no-bridge-present? = true and [is-no-bridge-present?] of node-to-connect = true [
      kill-no-bridge-max-degree
      ask node-to-connect [ kill-no-bridge-max-degree ]
      create-connection-with node-to-connect [ set active true ]
    ]
  ]
  [
    ifelse ( node-degree = node-max-degree ) [
      if is-no-bridge-present? = true [
        kill-no-bridge-max-degree
        ask node-to-connect [ increase-degree ]
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
    [
      if [is-no-bridge-present?] of node-to-connect = true [
        ask node-to-connect [ kill-no-bridge-max-degree ]
        increase-degree
        create-connection-with node-to-connect [ set active true ]
      ]
    ]
  ]
end

;;auxiliary procedure for "max-degree-no-bridge-kill"
to kill-no-bridge-max-degree
  let flag false
  let nodes-max-degree sort-by [ [node-degree] of ?1 > [node-degree] of ?2 ] connection-neighbors
  foreach nodes-max-degree [
   if is-bridge? ? = false [
     if flag = false [
       ask connection-with ? [ kill-connection ]
       set flag true
     ]
   ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Reports Procedures ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report edge-density
  report ( 2 * count connections ) / ( nodes-number * ( max-degree ) )
end

to-report get-bridges
  ifelse giant-component-nodes-number > 1 [
    report bridges  / giant-component-edges-number
  ]
  [
    report 0
  ]
end

;;returns true if among its
;;connections there is one which is not a bridge
to-report is-no-bridge-present?
  let flag false
  foreach sort my-connections [
    if is-bridge? ? = false [ set flag true ]
  ]
  report flag
end

;;outputs true if "conn" is a bridge
to-report is-bridge? [ conn ]
  let result false
  get-component self false
  let prev-local-component-nodes-number local-component-nodes-number
  if is-connection? conn [
    ask conn [ set active false ] ;; disable the link to make the test
    get-component self false
    if prev-local-component-nodes-number > local-component-nodes-number [
      set result true
    ]
    ask conn [ set active true ] ;; re-enable the link
  ]
  report result
end
@#$#@#$#@
GRAPHICS-WINDOW
662
6
1273
638
18
18
16.243243243243242
1
14
1
1
1
0
1
1
1
-18
18
-18
18
1
1
1
ticks
30.0

SLIDER
6
48
179
81
radius
radius
1
100
15
1
1
%
HORIZONTAL

SLIDER
189
48
362
81
max-degree
max-degree
1
nodes-number - 1
15
1
1
NIL
HORIZONTAL

SLIDER
6
14
179
47
nodes-number
nodes-number
2
100
80
1
1
NIL
HORIZONTAL

BUTTON
6
85
129
122
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
135
85
254
121
Step
move false 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
189
13
363
46
node-velocity
node-velocity
1
100
5
1
1
%
HORIZONTAL

SWITCH
268
126
379
159
all-different
all-different
0
1
-1000

BUTTON
6
125
129
159
Run simulation
move true 0
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
8
170
331
369
Growth of connected component
Time
Size
0.0
1.0
0.0
1.0
true
false
"" "get-giant-component"
PENS
"default" 1.0 0 -16777216 true "" "plot (giant-component-nodes-number / nodes-number)"

MONITOR
358
172
487
217
Giant component size
giant-component-nodes-number
1
1
11

PLOT
10
603
330
788
Edge Density
Time
Edge-Density
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot edge-density"

MONITOR
358
221
452
266
Connections
count connections
17
1
11

MONITOR
491
172
635
217
Connectivity (%)
(giant-component-nodes-number / nodes-number) * 100
3
1
11

MONITOR
455
221
560
266
Edge-Density (%)
edge-density * 100
3
1
11

PLOT
8
373
331
601
Bridges (%) in giant-component
Time
Bridges (%)
0.0
1.0
0.0
1.0
true
false
"" "count-bridges"
PENS
"default" 1.0 0 -16777216 true "" "plot get-bridges"

PLOT
336
569
630
788
Degree distribution
Degree
Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 false "set-plot-x-range 0 max-degree\nset-plot-y-range 0 nodes-number" "histogram [node-degree] of nodes"

MONITOR
358
269
448
314
Bridges (%)
get-bridges * 100
3
1
11

INPUTBOX
383
53
508
113
run-length
2000
1
0
Number

BUTTON
137
124
254
158
Go
move false 0
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
384
115
644
160
strategy
strategy
"Random-kill" "Max-degree-kill" "Most-distant-no-bridge-kill" "No-bridge-kill" "No-bridge-kill (random)" "No-bridge-kill (most-distant)" "No-bridge-kill (max-degree)" "Most-distant-kill" "Max-degree-no-bridge-kill"
2

SWITCH
510
80
637
113
export-plots
export-plots
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

thin ring
true
0
Circle -7500403 false true -2 -2 302

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Random strategy" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Random-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-degree strategy" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Max-degree-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="no-bridge-kill" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;No-bridge-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="most-distant-kill" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Most-distant-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-degree-no-bridge-kill" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Max-degree-no-bridge-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-degree-no-bridge-kill" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>move true random 1000</go>
    <steppedValueSet variable="nodes-number" first="70" step="10" last="90"/>
    <enumeratedValueSet variable="all-different">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="export-plots">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-degree" first="5" step="10" last="25"/>
    <enumeratedValueSet variable="radius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Most-distant-no-bridge-kill&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="node-velocity">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
