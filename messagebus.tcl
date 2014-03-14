# 
#   Implementation of message bus using the pub/sub mechanism
#
namespace eval Messagebus {

	variable subscriptions

	jsonrpc'has-on-connect-callback
	jsonrpc'has-on-close-callback

	#
	#	Subscribe your channel to a topic
	#
	proc subscribe {chan topic} {
		variable subscriptions
		dict lappend subscriptions $topic $chan
	}

	#
	#   Unsubscribe from a specific topic
	#
	proc unsubscribe {chan topic} {
		variable subscriptions
		set subscribed_channels [dict get $subscriptions $topic]
		set remove_this [lsearch $subscribed_channels $chan]

		if {$remove_this != -1} then {
			set without [lreplace $subscribed_channels $remove_this $remove_this]
			dict set subscriptions $topic $without
		}

	}

	#
	#   Get a list of subscriptions this channel is part of
	#
	proc subscriptions-for {chan} {
		variable subscriptions

		lappend chan_in

		foreach key [dict keys $subscriptions] {
			set chan_list [dict get $subscriptions $key]
			set idx [lsearch $chan_list $chan]

			if {$idx != -1} {
				lappend chan_in $key
			}
		}

		return $chan_in
	}

	#
	#	Get a set of unique topics people are subscribed to
	# 
	proc active-topics {} {
		variable subscriptions
		return [dict keys $subscriptions]
	}

	#
	# 	Put a message on the bus and distribute it to anyone listening
	#
	proc notify {topic message} {
		variable subscriptions

		# noone is even listening to this topic? 
		if {![dict exists $subscriptions $topic]} then {
			return
		}

		set topic_members [dict get $subscriptions $topic]

		foreach chan $topic_members {
			Websocket::send-message $chan $message
		}
	}

	#
	#	Make sure everyone that connects is part of the 'all' topic
	#
	proc on-connect {chan} {
		subscribe $chan "all"
	}

	#
	#   If someone closes the connection, make sure we are unsubscribing from everything
	#
	proc on-close {chan} {
		set subs [subscriptions-for $chan]
		foreach sub $subs {
		 	unsubscribe $chan $sub
		}
	}

}
