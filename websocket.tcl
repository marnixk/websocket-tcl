package require sha1
package require base64

namespace eval Websocket {

	# -> channel
	# 		-> url
	#		-> headers
	#			-> header -> value
	variable state
	variable guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	variable debug 0
	variable handling_namespace
	variable active_channels

	#
	#  Start a socket server
	#
	proc start {port {my_handling_namespace Websocket::MessageDispatcher}} {
		variable handling_namespace 

		set handling_namespace $my_handling_namespace

		socket -server accept $port 
		vwait forever
	}

	#
	#  Handler for accepting new connections
	#
	proc accept {chan addr port} {
		variable state
		variable active_channels

		puts "$addr:$port started"

		fconfigure $chan -buffering line
		fconfigure $chan -blocking 0
		fileevent $chan readable "Websocket::read-from-socket $chan"

		set state($chan) read-url
		set state($chan,connected) false
	}

	#
	#   Generic socket reader, makes sure to dispatch resulting line to 
	#   the active state handler
	#
	proc read-from-socket {chan} {
		variable state

		if { $state($chan,connected) != true } then {
			read-http-socket $chan
		} else {
			read-binary-socket $chan
		}
	}

	#
	#   Read from the http socket and dispatch it to the current state's handler
	#
	proc read-http-socket {chan} {
		variable state

		set left [gets $chan line]
		if { $left < 0 } {
			if { [eof $chan] } {
				close $chan
				return
			}
		} else {
			$state($chan) $chan $line
		}
	}


	#
	#   Allow the broadcasting of `message` to channels that are in the same space as
	#	`chan`. If exclude_self is set to '0', the message will also be sent to the 
	# 	current channel.
	#
	proc broadcast {src_chan message {exclude_self 1}} {
		variable active_channels
		variable handling_namespace

		set src_request_url [request-url $src_chan]

		# get a list of all channels on same url 
		foreach nominee $active_channels {

			# found self and need to skip?
			if { ${exclude_self} && $nominee == $src_chan } then {
				continue
			}

			set dst_request_url [request-url $nominee]
			if { $dst_request_url == $src_request_url } then {
				send-message $nominee $message
			}
		}
	}

	#
	#   Sending of messages using data framing as described here: 
	#	http://stackoverflow.com/questions/8125507/how-can-i-send-and-receive-websocket-messages-on-the-server-side
	#
	proc send-message {chan message} {

		set msg_length [string length $message]
		set output [to_char 129]

		if { $msg_length <= 125 } then {
			append output [to_char [expr {$msg_length & 0xff}]]
		} elseif { $msg_length >= 126 && $msg_length <= 65536 } {
			append output [to_char 126] 
			append output [to_char [expr { ($msg_length >> 8) & 0xff }]]
			append output [to_char [expr { $msg_length & 0xff }]]
		} else {
			append output [to_char 127]
			for { set idx 56 } { $idx >= 0 } { decr $idx 8} {
				append output [to_char [expr { ($msg_length >> $idx ) & 0xff }]]
			}
		}

		append output $message

		puts -nonewline $chan $output
	}

	#
	#   Decoding of messages: 
	# 	http://stackoverflow.com/questions/8125507/how-can-i-send-and-receive-websocket-messages-on-the-server-side
	#
	proc read-binary-socket {chan} {
		variable state
		variable handling_namespace
		variable active_channels

		# full binary data
		set input [read $chan]

		if { $input == "" } then {
			puts ".. connection closed."

			# remove chan from active channels list
			set chan_idx [lsearch $active_channels $chan]
			set active_channels [lreplace $active_channels $chan_idx $chan_idx]

			${handling_namespace}::on-close $chan
			close $chan
			return
		}

		# type at byte 0
		set type [to_byte $input 0]			

		# length at byte 1
		set length [to_byte $input 1]

		# and because 
		set length [expr {$length & 0x7f}]

		if { $length == 126 } then {
			set key_at 4
		} elseif { $length == 127 } then {
			set key_at 10
		} else {
			set key_at 2			
		}

		set data_start [expr {$key_at + 4}]

		set keys [list \
			[to_byte $input $key_at] \
			[to_byte $input [expr {$key_at + 1}]] \
			[to_byte $input [expr {$key_at + 2}]] \
			[to_byte $input [expr {$key_at + 3}]] \
		]

		set decoded ""

		set key_idx 0
		for {set idx $data_start} {$idx < [string length $input]} {incr idx} {

			set char_nr [to_byte $input $idx] 
			set active_key [lindex $keys $key_idx]
			set decoded_char_nr [expr { $char_nr ^ $active_key }]
			set newchar [to_char $decoded_char_nr]

			set decoded "$decoded$newchar"

			set key_idx [expr {($key_idx + 1) % 4}]
		}

		if { [catch { ${handling_namespace}::on-message $chan $decoded} error_msg error_trace ] } then {
			puts "------------- captured error ----------------------------------------"
			puts "Error occured: $error_msg"
			puts $error_trace
			puts "---------------------------------------------------------------------"

		}
	}

	# 
	#	Read the URL 
	#
	proc read-url {chan line} {
		variable state

		set url [lindex $line 1]
		puts ".. url - $url"

		set state($chan,url) $url
		set state($chan) read-headers
	}

	#
	#	Read headers from the request
	#
	proc read-headers {chan line} {
		variable state


		set headername [string range [lindex $line 0] 0 end-1]
		set value [string range $line [expr {2 + [string length $headername]}] end]
		
		log " .. $headername: $value"

		set state($chan,$headername) $value

		if {$line == ""} then {
			puts ".. done reading headers"
			set state($chan) read-messages
			send-handshake $chan
		}
	}

	#
	#	Calculate the handshake code based on the retrieved header key
	#
	proc send-handshake {chan} {
		variable state
		variable guid
		variable handling_namespace
		variable active_channels

		# setup the handshake key
		set concat_key "$state($chan,Sec-WebSocket-Key)$guid"
		set sha_hash [sha1::sha1 -bin $concat_key]
		set sha_base64 [base64::encode $sha_hash]

		if { $state($chan,Sec-WebSocket-Version) != 13 } then {
			puts "Don't know how to handle requests lower than v13."
			close $chan
		}

		puts ".. upgrading HTTP connection"

		puts $chan "HTTP/1.1 101 Switching Protocols"
		puts $chan "Upgrade: websocket"
		puts $chan "Connection: Upgrade"
		puts $chan "Sec-WebSocket-Accept: $sha_base64"
		puts $chan "Sec-WebSocket-Protocol: chat"
		puts $chan ""

		fconfigure $chan -translation binary
		fconfigure $chan -buffering none
		set state($chan,connected) true

		# add chan value to active channels
		lappend active_channels $chan

		${handling_namespace}::on-connect $chan

	}

	#
	#   Transform a character (or character at index in $char string) to a byte value
	#
	proc to_byte {char {index 0}} {
		set byte [scan [string index $char $index] %c]
		if {$byte == ""} then {
			return 0
		}
		return [expr $byte & 0xff]
	}

	#
	#   Convert a byte value to its character representative
	#
	proc to_char {byte} {
		return [format "%c" $byte]
	}

	#
	#	Log something to the console
	#
	proc log {text} {
		variable debug
		if {$debug != 0} then {
			puts "debug: $text"
		}
	}

	#
	#	Return the request url for a specific channel
	#
	proc request-url {chan} {
		variable state
		return $state($chan,url)
	}
}
