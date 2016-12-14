# eco-state-machine
Finite State Machine script for Godot Engine

This component is a standalone script with no dependency. It is compatible with every Godot version that supports signals and vcall.
It allows to make moderatly complex machines, with attributes, timers and groups. Conditions are custom defined with dynamic method calls. When a transition happens, wether it was manual or automatic, a signal is sent, which allows to execute code for specific transitions.

The machine is not meant to be extended but rather instanciated. By itself it doesn't manage parallel state machines, but nothing prevents to set multiple machines and have a manager who make them communicate.

Performance wise, this component is a gdscript and it won't be as fast as a FSM implemented in C++. But it's simple to use, powerful enough for complex programming, no dependency to any version and it gets the flexibility of gdscript.

![structure](/eco-state-machine-structure.png)

## Conditional links
This component features a state machine that can handle states and conditional links between them. It is possible to manually set a state or to let the machine determine is there's a state change (by calling its method "process(delta)").
If a condition is given, it can be of 2 kinds : 
* condition : calls a method of a node and compare it with an expected value.
* timeout : do the transition after a certain time.
and it is possible to combine a condition and a timer:
* timed condition : do the transition only if the condition is filled AND the timer is out.
It is possible to define multiple conditions for the same link, by simply adding more links between the same states. It will then act like a logical "OR".
Timers are either the time passed since the last state change or a custom defined timer. 

When a transition of a link happens, a signal "state_changed" is sent. It contains the informations about from which state to which state it moved. And a list of attributes is given in parameter too. This list is the concatenation of the attributes of the state and all imbricated groups the state belongs to. Since attributes are a dictionnary, each attribute has a name, and a state or subgroup can overwrite an attribute of a higher group. Attributes are however defined only once and they are constants.

## States
States are merely objects with a name and attributes. 
They must be declared before making a link between them.

## Groups
States can be regrouped in groups. Those groups can have conditional links to a state too. If a condition of a group whithin which the current state is located, the transition is made regardless the conditions of the current state.
It is possible to imbricate groups in other groups, without limit of depth.
Groups can have attributes like states.
Groups must be declared before they can be used.

## Priorities
If two or more conditions are fulfilled at the same time, the link with highest priority will be used for the transition.
The priority is automatically set in the same order of creation of the links. Links for groups have however more priority that state links. The top level group has the highest priority. States have the lowest priority. But within a same group/state, the first defined link will have the highest priority and the last defined link will have the lowest priority. 

## Timers
There a 2 kinds of timers: one automatically started when there's a change of state, and custom timers. The custom timers are defined with a name. Their typical usage is for groups, where it's sometimes whished to make a condition on the time passed since the group is entered.
Custom timers can be used by states and groups by adding them in the links.
Timers must be declared before they can be used.

There isn't actually any timer created in this script. The method "process(delta)" simply add to every declared timer the delta time and evaluated all conditions of the current state. Delta is a float parameter in seconds, typically given by _process or _fixed_process. But delta can be 0 or any numeric value if you don't want to use the machine in a _process.

## Examples

### Example 1
Let's consider a simple case of 2 states "a" and "b", where the machine switch from one state to the other every 3 seconds.
The code for the node that uses the machine would be like this:
```
extends Node

var fsm

func _ready():
    fsm=preload("fsm.gd")
    fsm.add_state("a")
    fsm.add_state("b")
    fsm.add_link("a","b","timeout",[3])
    fsm.add_link("b","a","timeout",[3])
    fsm.set_state("a")
    fsm.connect("state_changed",self,"on_state_changed")
    
    set_process(true)

func _process(delta):
    fsm.process(delta)

func on_state_changed(state_from,state_to,args):
    print("switched to state ",state_to)
```

### Example 2
A simple quizz, where the machine is updated when the player enters an answer:
![example 2](/eco-state-machine-example2.png)
```
extends Node
onready var fsm=preload("fsm.gd")
var player_answer=""

func _ready():
    fsm.add_state("question")
    fsm.add_state("right answer",{text:"You got it right!"})
    fsm.add_state("wrong answer",{text:"Wrong! Try another time."})
    fsm.add_link("question","right answer","condition",[self,"check_reply",true])
    fsm.add_link("question","wrong answer","condition",[self,"check_reply",false])
    fsm.set_state("question")
    fsm.connect("state_changed",self,"on_state_changed")

func enter_answer(answer):
    player_answer=answer
    fsm.process(0)

func check_reply():
    return player_answer=="sesame"

func on_state_changed(state_from,state_to,args):
    print(args.text)
    if state_to=="right answer":
        var score=1 # code to execute for the right answer

```
### Example 3
Example of a computer power management, slowly deactivating features and finally going to hibernation.
![example 3](/eco-state-machine-example3.png)
```
extends Node
onready var fsm=preload("fsm.gd")
var battery_level=100

func _ready():
    fsm.add_group("active")
    fsm.add_group("on battery",null,"active")
    fsm.add_state("hibernate")
    fsm.add_state("normal",null,"on battery")
    fsm.add_state("dim light",null,"on battery")
    fsm.add_state("screen off",null,"on battery")
    fsm.add_state("sleep",null,"on battery")
    fsm.add_state("charge",null,"active")
    
    fsm.add_link("on battery","charge","condition",[self,"is_charging","true"])
    fsm.add_link("charge","normal","condition",[self,"is_charging","false"])
    
    fsm.add_link("on battery","dim light","condition",[self,"battery_state","average"])
    fsm.add_link("on battery","screen off","condition",[self,"battery_state","low"])
    fsm.add_link("on battery","sleep","condition",[self,"battery_state","very low"])
    fsm.add_link("on battery","hibernate","condition",[self,"battery_state","critical"])
    
    fsm.add_link("active","hibernate","condition",[self,"power","off"])
    fsm.add_link("hibernate","normal","condition",[self,"power","on"])
    
    fsm.set_state("normal")
    fsm.connect("state_changed",self,"on_state_changed")
    
    set_process(true)

func _process(delta):
    fsm.process(delta)
    if is_charging():
        battery_level+=delta # recharge 1% every second
    else:
        battery_level-=delta/60 # consume 1% of battery every minute

func battery_state():
    if battery_level<5:
        return "critical"
    elif battery_level<10:
        return "very low"
    elif battery_level<25:
        return "low"
    elif battery_level<50:
        return "average"
    else:
        return "normal"

...

```

### Example 4
Turret bot, with a group and a timeout reset. The turret attacks target whenever it's in sight, and stops shooting after 5 seconds. The turret can be hit and be destroyed at any time. The turret shuts down automatically after 30 seconds.

![example 4](/eco-state-machine-example4.png)

```
extends Node
onready var fsm=preload("fsm.gd")

func _ready():
    fsm.add_timer("functional-timer")
    fsm.add_group("functional")
    fsm.add_state("idle",null,"functional")
    fsm.add_state("shoot",null,"functional")
    fsm.add_state("off")
    fsm.add_state("destroyed")
    fsm.add_link("functional","destroyed","condition",[self,"is_alive",false])
    fsm.add_link("idle","shoot","condition",[self,"is_target_on_sight"])
    fsm.add_link("shoot","idle","timeout",[5])
    fsm.add_link("functional","off","timeout",[30,"functional-timer"])
    fsm.set_state("idle")
    fsm.connect("state_changed",self,"on_state_changed")
    
    set_process(true)

func _process(delta):
    fsm.process(delta)

...

```
