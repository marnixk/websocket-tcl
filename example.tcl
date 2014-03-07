#!/usr/bin/tclsh

package require json

source "websocket.tcl"
source "messagedispatcher.tcl"
source "json.tcl"
source "jsonrpc-space.tcl"

namespace eval Action::echo {

	#
	#	Notify others about getting a message
	#
	proc notify-others {chan} {
		set output(message) [j' "hey guys! $chan here, just got a message!"]
		Websocket::broadcast $chan [json::encode [json::array output]]
	}

	proc on-message {chan json} {
		set in_msg [dict get $json msg]

		set output(status) [ j' "ok" ]
		set output(message) [ j' "echo: $chan, $in_msg" ]

		notify-others $chan
 
		return [array get output]
	}

}


Websocket::start 1337 