#!/usr/bin/tclsh

package require json

source "websocket.tcl"
source "messagedispatcher.tcl"
source "json.tcl"
source "jsonrpc-space.tcl"

namespace eval Action::echo {

	proc on-message {chan json} {
		set in_msg [dict get $json msg]

		set output(status) [ j' "ok" ]
		set output(message) [ j' "echo: $in_msg" ]

		return [array get output]
	}

}


Websocket::start 1337 Websocket::MessageDispatcher