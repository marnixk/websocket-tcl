websocket-tcl
=============

This is a very rudimentary WebSocket server implementation for TCL. It only works with version 13 of the WebSocket protocol as that is all that I needed. It is able to receive and send message.

The most minimalist WebSocket server can be started like this:

  #!/usr/bin/tclsh
  
  source "websocket.tcl"
  
  namespace eval MessageHandler {
  
  	proc on-message {chan message} {
  		Websocket::send-message $chan "This is my response to $message"
  	}
  
  }
  
  Websocket::start 1337 MessageHandler
