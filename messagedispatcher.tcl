#
#   Generic websocket message handler that is able to receive a message and
#   dispatch it to the correct "Space" namespace. The convention is to 
#   have the URL of the websocket connection influence the namespace on-message
#   proc that is called.
#
#   A connection on: `/jsonrpc`, will end up calling `Space::jsonrpc::on-message`
#
namespace eval Websocket::MessageDispatcher {

	#
	#   Get the name of the space to which calls for this chan are directed
	#
	proc request_space {chan} {

		set url [Websocket::request-url $chan]
		if { [string index $url 0] == "/" } then {
			set url [string range $url 1 end]
		}

		return "Space::$url"

	}

	#
	#   Forward closing call to the space 
	#
	proc on-close {chan} {
		set space [request_space $chan]
		${space}::on-close $chan
	}

	#
	#   Forward new connection call to the space 
	#
	proc on-connect {chan} {
		set space [request_space $chan]
		${space}::on-connect $chan
	}

	#
	#   Forward incoming message to correct space and output the resulting information
	#
	proc on-message {chan message} {

		set space [request_space $chan]

		# get output
		set output [${space}::on-message $chan $message]

		# clean it up
		set output [string trim $output]

		if { $output != "" } then {
			Websocket::send-message $chan $output
		}

	}

}