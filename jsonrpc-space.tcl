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

	proc error-message {msg {code 100}} {
		return [create errormessage {
				status "error"
				code $code
				error $msg
			}]
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

		# do message interceptions, stops processing when "stop-processing" is returned.
		foreach ns $on_message_callbacks {
			set filter_result [${ns}::on-message $chan $message]
			if {$filter_result == "stop-processing"} then {
				return
			}
		}

		# get tcl structure for json message
		set input [json::json2dict $message]
		
		# cast to 'message' struct
		set input [cast $input message]

		if { ![dict exists $input action] } then {
			set output [error-message "No action specified"]
		} else {

			set action [dict get $input action]
			
			if { ! [action-exists $action ] } then {
				set output [error-message "This action does not exist `$action`"]
			} else {
				set output [call-action $action $chan $input]

				# no return? just make it go away.
				if { [llength $output] == 0 } then {
					return ""
				}
			}
		}

		# make sure this is a struct
		if {[is-struct $output]} then {
			return [json::encode-struct $output]
		} 

		return -error "should only be outputting `structs`"
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
	lappend Space::jsonrpc::on_message_callbacks $calling_namespace
}

#
#	Create a message for the action called `name` with an array structured
#	list of elements in `payload` put as the payload attribute
#
proc jsonrpc'message {name payload} {
	set msg [create message { action $name payload $payload }]
	return [json::encode-struct $msg]
}

#
#
#
proc jsonrpc'respond-to {message} {
	set original [message.id message]

	# create response
	set response [create message]
	message.id reponse $original
	return $response

	# array set m_arr $message

	# if {[info exists m_arr(id)]} then {
	# 	set response(respond-to) [j' $m_arr(id)]
	# 	return [array get response]
	# }

	# return ""
}
