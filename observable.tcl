#
#	Implementation of observable data-structures. 
#
#	To monitor for changes in one or more variables use the || proc.
#		
#	|| {var1 var2} { lappend var2 "example" }

#	|| {var1->array var2->list} { lappend var2 "example" }
#	
#	This code will monitor var1 and var2 (they must exist before using), if one of the
#	variables changes its value, it gets sent on the "obs.var2" topic to whomever is listening
#	to it.
#

namespace eval Observable {

	#
	#	Wrap a json payload with the observable-update action wsbootstrap's observe listens to.
	#
	proc wrap-payload {name value} {
		set msg(action) [j' "observable-update"]
		set payload(name) [j' $name]
		set payload(value) $value
		set msg(payload) [json::array payload]
		return [json::encode [json::array msg]]
	}

	#
	#	'out of the box' list converter for values
	#
	proc convert-list {convertable} {
		return [j'list $convertable]
	}

	#
	#	'out of the box' converter for arrays
	#
	proc convert-array {convertable} {
		return [j'array $convertable]
	}

	#
	#	Subscribe a channel to a specific variable
	#
	proc subscribe {chan name} {
		Messagebus::subscribe $chan "obs.$name"
	}

	#
	#	Unsubscribe a channel from a variable.
	#
	proc unsubscribe {chan name} {
		Messagebus::unsubscribe $chan "obs.$name"
	}

}


#
#   Pipe implies piping changed information through the network to whomever is listening
#
proc || {watch body} {

	# record existing values
	foreach watch_var $watch {
		lassign [split $watch_var "->"] name _ type

		set source($name) [uplevel 1 set $name]
	}

	uplevel 1 $body

	foreach watch_var $watch {
		lassign [split $watch_var "->"] name _ type

		if {$type == ""} then {
			set type "list"
		}

		set currentval [uplevel 1 set $name]
		if {$currentval != $source($name)} then {
			Messagebus::notify "obs.$name" [Observable::wrap-payload $name [Observable::convert-$type $currentval]]
		}
	}

}
