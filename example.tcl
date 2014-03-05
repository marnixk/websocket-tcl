#!/usr/bin/tclsh

source "websocket.tcl"

namespace eval MessageHandler {

	proc on-message {chan message} {
		Websocket::send-message $chan "This is my response to $message"
	}

}

Websocket::start 1337 MessageHandler