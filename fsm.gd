class Group:
    var parent=null
    var links=null
    var attributes=null

class State:
    var attributes=null
    var parent=null
    var links:Array=[]

class Link:
    var next_state=null
    var type=null
    var timeout=0
    var timeout_arguments=[0,0]
    var has_timeout_constructed=false
    var timer=null
    var condition_method_owner=null
    var condition_signal_owner=null
    var condition_method=null
    var condition_arguments=[]
    var condition_expected
    var condition_signal=null
    var condition_signal_parameter=null
    var condition_signal_triggered=false

var timers={}
var groups={}
var states={}
var state_time=0
var current_state=null
var current_state_object:State=null
var links=[]
var uuid=load("res://player/addons/uuid/uuid.gd")
var current_state_id=null

signal state_changed(state_from,state_to,params,siganl_param)

func process(delta=0):
    if current_state==null or current_state_object==null or links.size()==0:
        return
    
    state_time+=delta
    for t in timers.keys():
        timers[t]+=delta
    
    for link in links:
        var condition=true
        var found=false
        if link.type=="timeout" or link.type=="timed condition":
            if link.timer!=null:
                condition=timers[link.timer]>link.timeout
            else:
                condition=state_time>link.timeout
            found=true
        if link.type=="timeout random":
            if !link.has_timeout_constructed:
                link.timeout=float(rand_range(link.timeout_arguments[0],link.timeout_arguments[1]))
                link.has_timeout_constructed=true
            if link.timer!=null:
                condition=timers[link.timer]>link.timeout
            else:
                condition=state_time>link.timeout
            found=true
        if condition and (link.type=="condition" or link.type=="timed condition" or (link.type=="signal condition" and link.condition_signal_triggered==true)) and link.condition_method_owner.has_method(link.condition_method):
            condition=condition and (link.condition_method_owner.callv(link.condition_method,link.condition_arguments)==link.condition_expected)
            found=true
        if condition and found:
            set_state(link.next_state)
            return
        

func set_state(new_state,siganl_param=null):
    state_time=0
    var old_state=current_state
    
    current_state=new_state
    current_state_object=states[current_state]
    current_state_id=uuid.v4()
    _rebuild_links()
    
    emit_signal("state_changed",old_state,new_state,get_groups_attributes(),siganl_param)
    
    

func init_signal_oneshot_condition_link(link):
    var _current_state_id=current_state_id
    while true:
        if _current_state_id==current_state_id:
            var signal_parameter=yield(link.condition_signal_owner,link.condition_signal)
            if _current_state_id==current_state_id:
                if link.condition_signal_parameter==null:
                    pass
                elif signal_parameter==link.condition_signal_parameter:
                    pass
                else:
                    continue
                if link.condition_method_owner.has_method(link.condition_method):
                    if link.condition_method_owner.callv(link.condition_method,link.condition_arguments)==link.condition_expected:
                        set_state(link.next_state,signal_parameter)
            else:
                break
        else:
            break
func init_signal_condition_link(link):
    var _current_state_id=current_state_id
    link.condition_signal_triggered=false
    while true:
        if _current_state_id==current_state_id:
            var signal_parameter=yield(link.condition_signal_owner,link.condition_signal)
            if _current_state_id==current_state_id:
                if link.condition_signal_parameter==null:
                    pass
                elif signal_parameter==link.condition_signal_parameter:
                    pass
                else:
                    continue
                if link.condition_method_owner.has_method(link.condition_method):
                    link.condition_signal_triggered=true
            else:
                break
        else:
            break
func init_signal_link(link):
    var _current_state_id=current_state_id
    while true:
        if _current_state_id==current_state_id:
            var signal_parameter=yield(link.condition_signal_owner,link.condition_signal)
            if _current_state_id==current_state_id:
                if link.condition_signal_parameter==null:
                    pass
                elif signal_parameter==link.condition_signal_parameter:
                    pass
                else:
                    continue
                set_state(link.next_state,signal_parameter)
            else:
                break
        else:
            break

func get_groups_attributes():
    var attributes
    if current_state_object.parent!=null:
        attributes=get_group_attributes(current_state_object.parent)
    else:
        attributes={}
    if current_state_object.attributes!=null:
        for a in current_state_object.attributes.keys():
            attributes[a]=current_state_object.attributes[a]
    return attributes

func get_group_attributes(group_name):
    var attributes
    var g=groups[group_name]
    if g.parent!=null:
        attributes=get_group_attributes(g.parent)
    else:
        attributes={}
    if g.attributes!=null:
        for a in g.attributes.keys():
            attributes[a]=g.attributes[a]
    return attributes

func _rebuild_links():
    links=[]
    if current_state_object.parent!=null:
        _fill_links(current_state_object.parent)
    if current_state_object.links!=null:
        for l in current_state_object.links:
            links.append(l)
            if l.type=="signal":
                init_signal_link(l)
            elif l.type=="signal oneshot condition":
                init_signal_oneshot_condition_link(l)
            elif l.type=="signal condition":
                init_signal_condition_link(l)

func _fill_links(group):
    if not groups.has(group):
        return
    
    var group_instance=groups[group]
    if group_instance.parent!=null:
        _fill_links(group_instance.parent)
    if group_instance.links!=null:
        for l in group_instance.links:
            links.append(l)
            if l.type=="signal":
                init_signal_link(l)
            elif l.type=="signal oneshot condition":
                init_signal_oneshot_condition_link(l)
            elif l.type=="signal condition":
                init_signal_condition_link(l)
func add_group(name,attributes=null,parent=null):
    var instance=Group.new()
    if attributes!=null:
        instance.attributes=attributes
    if parent!=null:
        instance.parent=parent
    groups[name]=instance

func add_state(name,attributes=null,group=null):
    var instance=State.new()
    if attributes!=null:
        instance.attributes=attributes
    if group!=null:
        instance.parent=group
    states[name]=instance

func add_link(state,next_state,type,params):
    if states.has(state):
        _add_link(states[state],next_state,type,params)
    elif groups.has(state):
        _add_link(groups[state],next_state,type,params)

func _add_link(instance,next_state,type,params):
    var link=Link.new()
    link.next_state=next_state
    link.type=type
    if type=="condition":
        link.condition_method_owner=params[0]
        link.condition_method=params[1]
        if params.size()==3:
            link.condition_expected=params[2]
        elif params.size()==4:
            link.condition_arguments=params[2]
            link.condition_expected=params[3]
    elif type=="timeout":
        link.timeout=params[0]
        if params.size()==2:
            link.timer=params[1]
    elif type=="timeout random":
        link.timeout_arguments=params[0]
        if params.size()==2:
            link.timer=params[1]
    elif type=="timed condition":
        link.timeout=params[0]
        link.condition_method_owner=params[1]
        link.condition_method=params[2]
        if params.size()==4:
            link.condition_expected=params[3]
        elif params.size()==5:
            if typeof(params[3])==TYPE_ARRAY:
                link.condition_arguments=params[3]
                link.condition_expected=params[4]
            else:
                link.condition_expected=params[4]
                link.timer=params[5]
        elif params.size()==6:
            link.condition_arguments=params[3]
            link.condition_expected=params[4]
            link.timer=params[5]
    elif type=="signal":
        link.condition_signal_owner=params[0]
        link.condition_signal=params[1]
        if params.size()==3:
            link.condition_signal_parameter=params[2]
    elif type=="signal oneshot condition" or type=="signal condition":
        link.condition_signal_owner=params[0]
        link.condition_signal=params[1]
        link.condition_signal_parameter=params[2]
        link.condition_method_owner=params[3]
        link.condition_method=params[4]
        if params.size()==6:
            link.condition_expected=params[5]
        elif params.size()==7:
            if typeof(params[5])==TYPE_ARRAY:
                link.condition_arguments=params[5]
                link.condition_expected=params[6]
            else:
                link.condition_expected=params[6]
                link.timer=params[7]
        elif params.size()==8:
            link.condition_arguments=params[5]
            link.condition_expected=params[6]
            link.timer=params[7]
    if instance.links==null:
        instance.links=[]
    instance.links.append(link)

func add_timer(name):
    timers[name]=0

#added func
func get_current_group():
    return states[current_state].parent
