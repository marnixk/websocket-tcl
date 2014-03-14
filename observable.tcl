
namespace eval Observable {

	proc wrap-payload {name value} {
		set msg(action) [j' "observable-update"]
		set msg(name) [j' $name]
		set msg(value) $value
		return [json::encode [json::array msg]]
	}

	proc convert-list {convertable} {
		return [j'list $convertable]
	}

	proc subscribe {chan name} {
		Messagebus::subscribe $chan "obs.$name"
	}

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