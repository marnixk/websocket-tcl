#
#    Simple echo space.
#
namespace eval Space::jsonrpc {

	variable on_connect_callbacks [list]
	variable on_close_callbacks [list]
	variable on_message_callbacks [list]

	#
	#   When a new connection to this space is created, this method is called
	#
	proc on-connect {chan} {
		variable on_connect_callbacks
		foreach ns $on_connect_callbacks {
			${ns}::on-connect $chan
		}
	}

	#
	#	When the user closes the connection for this space, handle it here.
	#
	proc on-close {chan} {
		variable on_close_callbacks
		foreach ns $on_close_callbacks {
			${ns}::on-close $chan
		}
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
		variable on_message_callbacks
		
		foreach ns $on_message_callbacks {
			${ns}::on-message $chan $message
		}

		# get tcl structure for json message
		set input [json::json2dict $message]

		if { ![dict exists $input action] } then {
			error-message output "No action specified"
		} else {

			set action [dict get $input action]
			
			if { ! [action-exists $action ] } then {
				error-message output "This action does not exist `$action`" 
			} else {
				array set output [call-action $action $chan $input]

				# no return? just make it go away.
				if { [array size output] == 0 } then {
					return ""
				}
			}
		}

		# encoded message to send.
		return [json::encode [json::array output]]
	}

}

#
#	This proc is used to register custom on-connect callback handlers, this will
#	allow you to automatically subscribe channels to correct observational elements.
#
proc jsonrpc'has-on-connect-callback {} {
	set calling_namespace [uplevel 1 namespace current]
	lappend Space::jsonrpc::on_connect_callbacks $calling_namespace
}

#
# 	This proc is used to register custom on-close callback handlers
#
proc jsonrpc'has-on-close-callback {} {
	set calling_namespace [uplevel 1 namespace current]
	lappend Space::jsonrpc::on_close_callbacks $calling_namespace
}

#
#   This proc enables a namespace outside the normal Action::<eventname> namespaces
#	to intercept each request and handle them accordingly.
#
proc jsonrpc'has-on-message-callback {} {
	set calling_namespace [uplevel 1 namespace current]
	lappend Space::jsonrpc::on_close_callbacks $calling_namespace
}

#
#	Create a message for the action called `name` with an array structured
#	list of elements in `content` put as the payload attribute
#
proc jsonrpc'message {name content} {
	set output(action) [j' $name]
	array set content_out $content
	set output(payload) [json::array content_out]
	return [json::encode [json::array output]]
}

#
#
#
proc jsonrpc'respond-to {message} {
	array set m_arr $message

	if {[info exists m_arr(id)]} then {
		set response(respond-to) [j' $m_arr(id)]
		return [array get response]
	}

	return ""
}
