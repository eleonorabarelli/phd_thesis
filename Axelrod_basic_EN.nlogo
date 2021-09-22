;; Axelrod's Model for Cultural Evolution is an agent-based model described by
;; Robert Axelrod in his paper:
;; Axelrod, R. 1997. “The dissemination of culture - A model with local convergence and global polarization.”
;;        Journal of Conflict Resolution 41:203-226.
;;
;;
;; 2021 Eleonora Barelli (eleonora.barelli2@unibo.it)
;;
;; -------------------------------------------------- ;;

;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals [
  time                            ;; time
  number_of_agents                ;; number of all agents in the society (obtained as world-size^2)
  cult_max                        ;; number associated to the culture with maximum traits for each feature [q-1, q-1, q-1, …, q-1]
  number_of_active_agents         ;; number of agents which have at least one neighbor with overlap in ]0,F[
  number_of_cultures              ;; number of cultures in the society at a certain time
  number_of_cultural_regions      ;; number of cultural regions simply connected
  component-size                  ;; number of agents explored so far in the current component
  giant-component-size            ;; number of agents in the giant component
]

turtles-own [
  culture                         ;; culture of an agent
  explored?                       ;; if the agent is already explored (or not) when determining number of cultural regions
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; General setup settings: clear plots, create the grid
;;
to setup
  clear-all
  clear-all-plots
  resize-world 0 (world-size - 1) 0 (world-size - 1)   ;; defining the size of the society
  set number_of_agents (world-size * world-size)       ;; there will be as many agents as the patches (not yet created)
  set-patch-size 360 / world-size                      ;; setting patch size for good looking
  ask patches [set pcolor 34]                          ;; setting color of patches
  set giant-component-size 0                           ;; initializing the number of agents in the biggest cultural domain
  set number_of_cultural_regions 0                     ;; initializing the number of the cultural regions
  setup-turtles                                        ;; creating the agents, locating them and setting their cultural values randomly
  reset-ticks
  set time 0
end

;;
;; Agent settings: create agents, position them in the grid
;;
to setup-turtles
  set-default-shape turtles "person"
  create-turtles number_of_agents [                    ;; creating the agents
    set size 0.9
    while [any? other turtles-here] [ move-to one-of patches ] ;; setting agents' location: only one agent at each patch
  ]
  setup-culture-max                                    ;; assigning a value to the culture with maximum traits value
  setup-agent-culture                                  ;; setting agents culture
  count-cultures                                       ;; counting the amount of different cultures at time = 0
  do-plots                                             ;; plotting for visualization
end

;;
;; Assigning a value to the culture with maximum traits values
;;
to setup-culture-max
  set cult_max (q ^ F - 1)
end

;;
;; Assigning a random culture to each agent
;;
to setup-agent-culture
  ask turtles [                               ;; all agents, in a random order, are asked to
    set culture []                            ;; set their own variable “culture” to an empty list, then,
    repeat F [                                ;; F (number of cultural features) times,
      set culture lput random q culture       ;; add at the end of the list a random value in [0, q-1].
    ]                                         ;; Once the list is filled,
    setup-agent-culture-color                 ;; set a color for the agent according to its culture
  ]
end

;;
;; Setting the color to the agent according to its culture
;;
to setup-agent-culture-color
  ;setting agent culture in base q
  let i 1
  let suma 0
  repeat F [
    set suma suma + item (i - 1) culture * q ^ (F - i)
    set i i + 1
  ]
  let Cult_base_q suma
  ;setting the corresponding color to the turtle according to the culture_base_q value. a range of blue is selected
  set color (9.9 * Cult_base_q / Cult_max) + 100
end

;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN PROCEDURE ;;;
;;;;;;;;;;;;;;;;;;;;;;

;;
;; Execute all the procedures in their order until there are active agents
;;
to go
  clear-links
  ask turtles [setup-agent-culture-color]                          ;; asking agents to setup their color
  tick
  set time time + 1
  set number_of_active_agents 0
  ask turtles [cultural-interaction]                               ;; asking agents to interact locally in asyncronous-random updating
  count-cultures                                                   ;; counting the amount of different cultures
  do-plots                                                         ;; plotting for visualization
  if number_of_active_agents = 0 [stop]                            ;; stopping when there are no active agents (when each agent
                                                                   ;;    has full or null overlap with each of its neighbors
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;; LOCAL PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; agents look for a neighbor to interact with
;;
to cultural-interaction
  ; count the neighbors within the given radius that have a number of common traits in ]0, F[
  let number_of_possible_neighbors count other turtles in-radius radius with [(0 < overlap_between self myself ) and (overlap_between self myself < F)]
  ; if there is one or more such neighbors,
  if number_of_possible_neighbors > 0 [
    ; increase of 1 the number of active agents and
    set number_of_active_agents number_of_active_agents + 1
    ; select a neighbor within the radius
    let neighbor_turtle one-of other turtles in-radius radius
    ; and make it interact with the target agent
    let target_turtle self
    culturally_interacting target_turtle neighbor_turtle
  ]
end

;;
;; reporting overlap between two agents (range from 0 to F)
;;
to-report overlap_between [target_turtle neighbor_turtle]
  let suma 0                                                         ;; Initialize to 0 a temporarily variable suma, then
  (foreach [culture] of target_turtle [culture] of neighbor_turtle   ;; for each element of the cultures of target and neighbor,
    [ [a b] -> if a = b [ set suma suma + 1]  ]                      ;; compare the traits and, if they are equal, add 1 to suma
    )
  report suma
end

;;
;; interaction between a target agent and its selected neighbor
;;
to culturally_interacting [target_turtle neighbor_turtle]
  let overlap overlap_between target_turtle neighbor_turtle                       ;; Calculate the overlap between target and neighbor.
  if (0 < overlap and overlap < F ) [                                             ;; If the overlap is in ]0, F[,
    let prob_interaction (overlap / F)                                            ;; call overlap/F the probability of interaction, then,
    if random-float 1.0 < prob_interaction [                                      ;; according to this probability,
      let trait random F                                                          ;; select randomly a cultural feature to inspect
      let trait_selected? false
      while [not trait_selected?] [
        ifelse (item trait [culture] of target_turtle = item trait [culture] of neighbor_turtle)   ;; if that cultural feature has the same trait for both agents
        [
          set trait ((trait + 1) mod F)                                           ;; pass to the adjacent cultural feature
        ]
        [
          set trait_selected? true                                                ;; otherwise
        ]
      ]
      let new_cultural_value (item trait [culture] of neighbor_turtle)            ;; save the trait for that cultural feature of the neighbor
      set culture replace-item trait culture new_cultural_value                   ;; and replace the original cultural feature in the target agent with the neighbor’s trait
      setup-agent-culture-color                                                   ;; update the target agent's color according to the new culture
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; COMPONENT EXPLORATION ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; Find all agents reachable from this node (it is a recursive procedure)
;;
to explore ;; turtle procedure
  if explored? [ stop ]
  set explored? true
  set component-size component-size + 1
  ask link-neighbors [ explore ]
end

;;
;; an agent creates a link with all its neighbors with the same culture
;;
to creates-links-with-same-cultural-neighbors-in-neighborhood-of-radio-radius
  let neighborhood other turtles in-radius radius
  ask neighborhood [
    if overlap_between self myself = F                              ;; if they have the same cultures
    [
      let color_for_the_link color
      create-link-with myself [set color color_for_the_link]        ;; create a link
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GLOBAL EXPLORATION ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; count the number of different cultures in the system
;;
to count-cultures
  let list_of_cultures []                                          ;; Initialize an empty list to contain the different cultures
  ask turtles [                                                    ;; All agents, in random order, are asked to
    set list_of_cultures lput culture list_of_cultures             ;; add their vector of culture to the list of cultures.
    ]
  set list_of_cultures remove-duplicates list_of_cultures          ;; Remove the duplicates from the resulting list
  set number_of_cultures length list_of_cultures                   ;; The number of different cultures is the length of the list
end

;;
;; counting the number of agents in the biggest cultural region
;;
to count-turtles-on-biggest-region
  ; first it is linked all agents of the same culture (each agent looks for a neighbor which is in its neighborhood (agent inside in radius)
  ask turtles [
    creates-links-with-same-cultural-neighbors-in-neighborhood-of-radio-radius
  ]
  find-all-components                                                  ;; exploring each connected network finding and counting agents of the same culture
end

;;
;; finding all the connected components in the network and their sizes
;;
to find-all-components
  set number_of_cultural_regions 0                             ;; Initialize to 0 the number of cultural regions
  ask turtles [ set explored? false]                           ;; All the agents, until all get explored, are asked to
  loop
  [
    let starting_turtle one-of turtles with [ not explored? ]  ;; find a starting agent that has not been yet explored
    if starting_turtle = nobody [ stop ]                       ;; (if no agents are left, the loop stops)
    set component-size 0                                       ;; Initialize to 0 the component size
    ask starting_turtle [                                      ;; Ask the starting agent to
      explore                                                  ;; Count its similar neighbors (recursive procedure
                                                               ;; in which the component-size counter is updated)
      set number_of_cultural_regions number_of_cultural_regions + 1   ;; Once the explore procedure ends, increase the number of cultural regions
    ]
    if component-size > giant-component-size [                 ;; If the component explored is bigger than the giant component,
      set giant-component-size component-size                  ;; call its dimension the giant-component-size
    ]
  ]
end

;;;;;;;;;;;;;;
;;; GRAPHS ;;;
;;;;;;;;;;;;;;

to do-plots
  ;setting the plot of Cultures
  set-current-plot "Graph"
  set-current-plot-pen "Number of cultures"
  plotxy time (number_of_cultures / q ^ F)
end
@#$#@#$#@
GRAPHICS-WINDOW
162
10
530
379
-1
-1
36.0
1
15
1
1
1
0
0
0
1
0
9
0
9
1
1
1
ticks
30.0

BUTTON
4
10
73
43
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
4
192
126
225
Go Once
go
NIL
1
T
OBSERVER
NIL
O
NIL
NIL
1

INPUTBOX
4
84
54
144
F
3.0
1
0
Number

INPUTBOX
57
84
107
144
q
5.0
1
0
Number

INPUTBOX
108
84
158
144
radius
1.0
1
0
Number

PLOT
536
10
941
214
Graph
time
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Number of cultures" 1.0 0 -16777216 true "" ""

MONITOR
536
219
671
264
Number of cultures
number_of_cultures
17
1
11

MONITOR
657
276
798
321
Giant Component Size
giant-component-size
17
1
11

MONITOR
657
326
814
371
Number of cultural regions
number_of_cultural_regions
17
1
11

MONITOR
801
276
1010
321
Normalized Giant Component Size
giant-component-size / number_of_agents
17
1
11

MONITOR
817
326
1010
371
Normalized No. of Cultural Regions
number_of_cultural_regions / number_of_agents
17
1
11

SLIDER
4
45
158
78
world-size
world-size
2
60
10.0
1
1
NIL
HORIZONTAL

BUTTON
3
156
125
189
Go Forever
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
538
304
650
337
Report Networks
count-turtles-on-biggest-region
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

@#$#@#$#@
## THE MODEL

It is an agent-based simulation of the Axelrod model for cultural diffusion. The simulation allows to explore the evolution of a system on the basis of the cultural characteristics of the agents that compose it.
The dynamics of the model is based on two main mechanisms: (1) the agents tend to interact with other agents who have similar cultural characteristics and (2) during the interaction, the agents influence each other in order to become more similar.
This dynamic sometimes leads to cultural homogeneity in which all agents have the same cultural characteristics, but at other times it makes culturally distinct regions develop. The model allows to study to what extent the probability of these two results depends on the parameters of the model:
- the number of agents in the population
- F, the number of cultural characteristics considered
- q, the number of values ​​that each characteristic can assume (also called cultural traits)
- r, the radius of interaction

## THE RULES

Each agent occupies a single cell of a square grid. The culture of an agent is described by a vector of F integer variables called "features". Each of these features can assume q different values ​​(called "traits") between 0 and q-1. Initially, the characteristics of each agent have random traits.
At each tick of the model, agents update their cultural value via an asynchronous random update. This means that the program creates a list in which all agents are included in a random order and the list is parsed until all agents are chosen.
When an agent's turn comes, one of its neighbors (i.e. one of the agents within the set radius) is randomly selected.
Between the agent and his neighbor, the cultural overlap is then calculated as the percentage of characteristics with equal traits. For example, between an agent described by the vector [8,2,3,3,0] and its neighbor described by the vector [6,3,7,3,0], the cultural overlap will be 2/5, that is 40%.
Then, with probability equal to the overlap, the two agents interact. An interaction consists in randomly selecting one of the features on which the two agents differ and in modifying the feature of the agent considered with that of the neighbor with whom it interacts. Note that, if the overlap is equal to 0, the interaction is not possible and the respective agents are not influenced. Similarly, if the overlap is equal to 1, there is no interaction because the values ​​of all the traits are already equal between the two agents.
This procedure continues until there are active agents on the grid, that is that there are agents that have at least one neighbor with neither zero nor total overlap.

## USE OF THE SIMULATION

The user can choose the size of the population (via "world-size"), the number of cultural characteristics considered (F), the number of cultural traits (q) and the range of interaction (radius). When the radius is equal to 1, the neighborhood of each agent consists of the 4 agents immediately above, below, right and left (following the Von Neumann topology). 
Pressing 'Setup' the user initializes the system with the selected parameters. “Go Once” or “Go Forever” make the simulation start. The simulation allows the user to follow the changes in the culture of the agents based on the color they take on. In addition, a graph reports the number of different cultures at each tick of the simulation. 
At the end of the simulation, through “Report Networks” it is possible to obtain the number of cultural regions in the population (regions with adjacent agents of the same culture) and the number of agents in the largest region.

## REFERENCES

This model was developed by Robert Axelrod. The 1997 paper in which the author presents the model is:

Axelrod, R. 1997. "The dissemination of culture - A model with local convergence and global polarization." Journal of Conflict Resolution 41: 203-226.

ThIS NetLogo simulation has been adapted for educational purposes by Eleonora Barelli (eleonora.barelli2@unibo.it) starting from the code of Arezky H. Rodríguez (arezky@gmail.com).

© 2021 by Eleonora Barelli (eleonora.barelli2@unibo.it)
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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
