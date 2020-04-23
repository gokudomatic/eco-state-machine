# eco-state-machine
Finite State Machine script for Godot Engine

This component is a standalone script with no dependency. It is compatible with every Godot version that supports signals and vcall.
It allows to make moderatly complex machines, with attributes, timers and groups. Conditions are custom defined with dynamic method calls. When a transition happens, whether it was manual or automatic, a signal is sent, which allows to execute code for specific transitions.

The machine is not meant to be extended but rather instanciated. By itself it doesn't manage parallel state machines, but nothing prevents to set multiple machines and have a manager who make them communicate.

Performance wise, this component is a gdscript and it won't be as fast as a FSM implemented in C++. But it's simple to use, powerful enough for complex programming, no dependency to any version and it gets the flexibility of gdscript.

This is the kind of complexity you can achieve with this component:
![structure](/eco-state-machine-structure.png)


## States
States are merely objects with a name and attributes. 
They must be declared before making a link between them.

Code:
```python
add_state(state_name,attributes=null,parent_group_name=null)
```

## Groups
States can be regrouped in groups. Those groups can have conditional links to a state too. If a condition of a group whithin which the current state is located, the transition is made regardless the conditions of the current state.
It is possible to imbricate groups in other groups, without limit of depth.
Groups can have attributes like states.
Groups must be declared before they can be used.

Code:
```python
add_group(group_name,attributes=null,parent_group=null)
```

## Priorities
If two or more conditions are fulfilled at the same time, the link with highest priority will be used for the transition.
The priority is automatically set in the same order of creation of the links. Links for groups have however more priority that state links. The top level group has the highest priority. States have the lowest priority. But within a same group/state, the first defined link will have the highest priority and the last defined link will have the lowest priority. 

## Timers
There a 2 kinds of timers: one automatically started when there's a change of state, and custom timers. The custom timers are defined with a name. Their typical usage is for groups, where it's sometimes whished to make a condition on the time passed since the group is entered.
Custom timers can be used by states and groups by adding them in the links.
Timers must be declared before they can be used.

There isn't actually any timer created in this script. The method "process(delta)" simply adds to every declared timer the delta time and evaluated all conditions of the current state. Delta is a float parameter in seconds, typically given by _process or _fixed_process. But delta can be 0 or any numeric value if you don't want to use the machine in a _process.

Code:
```python
add_timer(timer_name)
```

## Conditional links
This component features a state machine that can handle states and conditional links between them. It is possible to manually set a state or to let the machine determine if there's a state change (by calling its method "process(delta)").
If a condition is given, it can be of 2 kinds : 
* condition : calls a method of a node and compare it with an expected value.
* timeout : do the transition after a certain time.
and it is possible to combine a condition and a timer:
* timed condition : do the transition only if the condition is filled AND the timer is out.

It is possible to define multiple conditions for the same link, by simply adding more links between the same states. It will then act like a logical "OR".
Timers are either the time passed since the last state change or a custom defined timer. 

When a transition of a link happens, a signal "state_changed" is sent. It contains the information about from which state to which state it moved, and a list of attributes is given as parameters. This list is the concatenation of the attributes of the state and all imbricated groups the state belongs to. Since attributes are a dictionary, each attribute has a name, and a state or subgroup can overwrite an attribute of a higher group. Attributes are however defined only once and they are constants.

Code:
```python
add_link(origin_state_name,destination_state_name,condition_type,parameters)
```
here parameters are different regarding the condition type:
* condition : 
```python
parameters = [condition_method_owner, condition_method, condition_arguments = [], condition_expected]
```
* timed_condition:
```python
params = [timeout, condition_method_owner, condition_method, condition_arguments = [], condition_expected, timer = null]
```
* timeout:
```python
params = [timeout, timer = null]
```
* random timeout:
```python
params = [[time_min,time_max]]
```
* signal:
```python
params = [signal_owner,signal]
```
* signal oneshot condition: (will not check in _process,just check once when signal is triggered)
```python
params = [signal_owner,signal,signal_param,condition_method_owner,condition_method,condition_arguments = [], condition_expected]
```
* signal condition:(will check in _process for many times when signal is triggered)
```python
params = [signal_owner,signal,signal_param,condition_method_owner,condition_method,condition_arguments = [], condition_expected]
```

## Examples

### Example 1
Let's consider a simple case of 2 states "a" and "b", where the machine switchs from one state to the other every 3 seconds.
The code for the node that uses the machine would be like this:
```python
extends Node

var fsm

func _ready():
    fsm=preload("fsm.gd").new()
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
A simple quiz, where the machine is updated when the player enters an answer:
![example 2](/eco-state-machine-example2.png)
```python
extends Node
onready var fsm=preload("fsm.gd").new()
var player_answer=""

func _ready():
    fsm.add_state("question")
    fsm.add_state("right answer",{'text':"You got it right!"})
    fsm.add_state("wrong answer",{'text':"Wrong! Try another time."})
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
```python
extends Node
onready var fsm=preload("fsm.gd").new()
var battery_level=100
var charging=false
var power=true

func _ready():
    fsm.add_group("active")
    fsm.add_group("on battery",null,"active")
    fsm.add_state("hibernate")
    fsm.add_state("normal",null,"on battery")
    fsm.add_state("dim light",null,"on battery")
    fsm.add_state("screen off",null,"on battery")
    fsm.add_state("sleep",null,"on battery")
    fsm.add_state("charge",null,"active")
    
    fsm.add_link("on battery","charge","condition",[self,"is_charging",true])
    fsm.add_link("charge","normal","condition",[self,"is_charging",false])
    
    fsm.add_link("on battery","dim light","condition",[self,"battery_state","average"])
    fsm.add_link("on battery","screen off","condition",[self,"battery_state","low"])
    fsm.add_link("on battery","sleep","condition",[self,"battery_state","very low"])
    fsm.add_link("on battery","hibernate","condition",[self,"battery_state","critical"])
    
    fsm.add_link("active","hibernate","condition",[self,"check_power","off"])
    fsm.add_link("hibernate","normal","condition",[self,"check_power","on"])
    
    fsm.set_state("normal")
    fsm.connect("state_changed",self,"on_state_changed")
    
    set_process(true)

func _process(delta):
    fsm.process(delta)
    if is_charging():
        battery_level+=delta # recharge 1% every second
    else:
        if power:
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

func check_power():
    if power:
        return "on"
    else:
        return "off"

func is_charging():
    return charging

func on_state_changed(state_from,state_to,args):
...

```

### Example 4
Turret bot, with a group and a timeout reset. The turret attacks target whenever it's in sight, and stops shooting after 5 seconds. The turret can be hit and destroyed at any time. The turret shuts down automatically after 30 seconds.

![example 4](/eco-state-machine-example4.png)

```python
extends Node
onready var fsm=preload("fsm.gd").new()

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

### Example 5
Basic Third Person Melee State Machine with STAND -> ROLL -> STAND,STAND -> JUMP ->STAND,STAND -> FIRE -> STAND,STAND -> BLOCK -> STAND,STAND -> SKILL -> STAND

```python
enum STATE_BASE{
    STAND,
    ROLL,
    JUMP,
    FIRE,
    SKILL,
    BLOCK,
   }
func init_fsm_base():
    fsm_base=preload("res://Script/fsm.gd").new()
    fsm_base.add_state(STATE_BASE.STAND)
    fsm_base.add_state(STATE_BASE.ROLL)
    fsm_base.add_state(STATE_BASE.JUMP)
    fsm_base.add_state(STATE_BASE.FIRE)
    fsm_base.add_state(STATE_BASE.SKILL)
    fsm_base.add_state(STATE_BASE.BLOCK)
    
    
    fsm_base.add_link(STATE_BASE.STAND,STATE_BASE.ROLL,"signal",[self,"roll"])
    fsm_base.add_link(STATE_BASE.ROLL,STATE_BASE.STAND,"condition",[self,"fsm_roll_to_idle",STATE_BASE.STAND])
    
    fsm_base.add_link(STATE_BASE.STAND,STATE_BASE.JUMP,"signal",[self,"jump"])
    fsm_base.add_link(STATE_BASE.JUMP,STATE_BASE.STAND,"condition",[self,"fsm_jump_to_idle",STATE_BASE.STAND])
    
    fsm_base.add_link(STATE_BASE.STAND,STATE_BASE.FIRE,"signal",[self,"fire"])
    fsm_base.add_link(STATE_BASE.FIRE,STATE_BASE.STAND,"condition",[self,"fsm_fire_to_idle",STATE_BASE.STAND])
    
    #skill
    fsm_base.add_link(STATE_BASE.STAND,STATE_BASE.SKILL,"signal",[self,"skill"])
    fsm_base.add_link(STATE_BASE.SKILL,STATE_BASE.STAND,"condition",[self,"fsm_base_skill_to_idle",[ skill_index_ref],STATE_BASE.STAND])
    
    #block
    fsm_base.add_link(STATE_BASE.STAND,STATE_BASE.BLOCK,"signal",[self,"block"])
    fsm_base.add_link(STATE_BASE.BLOCK,STATE_BASE.STAND,"signal condition",[self,'block_end',null,self,"fsm_base_block_to_idle",STATE_BASE.STAND])
    
    fsm_base.set_state(STATE_BASE.STAND)
    fsm_base.connect("state_changed",self,"on_state_base_changed")

...

```

### Example 6
Basic Third Person Shooter Aim State Machine

```python
enum STATE_AIM{
    IDLE,
    FIRE,
    HOLD,#holding the weapon
    TARGET,
    TARGET_CONTTINUOUS,
    SKILL,
   }
func init_fsm_aim():
    fsm_aim=preload("res://Script/fsm.gd").new()
    
    fsm_aim.add_state(STATE_AIM.IDLE)
    fsm_aim.add_state(STATE_AIM.FIRE)
    fsm_aim.add_state(STATE_AIM.HOLD)
    fsm_aim.add_state(STATE_AIM.TARGET_CONTTINUOUS)
    fsm_aim.add_state(STATE_AIM.SKILL)
    
    #fire
    fsm_aim.add_link(STATE_AIM.HOLD,STATE_AIM.FIRE,"signal oneshot condition",[self,"fire",null,self,"fsm_aim_to_fire",STATE_AIM.FIRE])
    fsm_aim.add_link(STATE_AIM.FIRE,STATE_AIM.TARGET_CONTTINUOUS,"condition",[self,"_true",true])
    fsm_aim.add_link(STATE_AIM.TARGET_CONTTINUOUS,STATE_AIM.FIRE,"signal oneshot condition",[self,"fire",null,self,"fsm_aim_to_fire",STATE_AIM.FIRE])
    
    #skill
    fsm_aim.add_link(STATE_AIM.HOLD,STATE_AIM.SKILL,"signal oneshot condition",[self,"skill",null,self,"fsm_aim_to_skill",STATE_AIM.SKILL])
    fsm_aim.add_link(STATE_AIM.SKILL,STATE_AIM.TARGET_CONTTINUOUS,"condition",[self,"_true",true])
    fsm_aim.add_link(STATE_AIM.TARGET_CONTTINUOUS,STATE_AIM.SKILL,"signal oneshot condition",[self,"skill",null,self,"fsm_aim_to_skill",STATE_AIM.SKILL])
    
    fsm_aim.add_link(STATE_AIM.TARGET_CONTTINUOUS,STATE_AIM.HOLD,"signal",[fire_targeting_timer,"timeout"])
    
    fsm_aim.set_state(STATE_AIM.HOLD)
    fsm_aim.connect("state_changed",self,"on_state_aim_changed")
...

```
