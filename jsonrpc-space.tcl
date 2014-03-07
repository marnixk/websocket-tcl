
#
#    Simple echo space.
#
namespace eval Space::jsonrpc {

	#
	#   When a new connection to this space is created, this method is called
	#
	proc on-connect {chan} {
	}

	#
	#	When the user closes the connection for this space, handle it here.
	#
	proc on-close {chan} {
	}

	proc error-message {r_output msg {code 100}} {
		upvar 1 $r_output output

		set output(status) [ j' "error" ]
		set output(code) [ j' $code ]
		set output(error) [ j' $msg ]
	}

	#
	#	Determines whether the action exists or not
	#
	proc action-exists {action_name} {
		set full_ns "::Action::$action_name"
		return [namespace exists $full_ns]	
	}

	#
	#	Actually calls the action
	#
	proc call-action {action_name chan input} {
		return [Action::${action_name}::on-message $chan $input]
	}

	#
	#   When a message is received, handle it here. 
	#
	proc on-message {chan message} {

		# get tcl structure for json message
		set input [json::json2dict $message]

		if { ![dict exists $input action] } then {
			error-message output "No action specified"
		} else {

			set action [dict get $input action]
			
			if { ! [action-exists $action ] } then {
				error-message output "This action does not exist" 
			} else {
				array set output [call-action $action $chan $input]
			}
		}

		# encoded message to send.
		return [json::encode [json::array output]]
	}

}