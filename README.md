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

This starts a new server on port 1337, that passes messages to `MessageHandler` namespace's `on-message` proc.

## Default MessageDispatcher

This package comes with a default message dispatcher that uses the URL the websocket connected on as a reference point for the destination of an incoming message. 

If someone connects on `ws://localhost:1337/jsonrpc` it will redirect the incoming message to `on-message` in the namespace called `Space::jsonrpc`. The default signature of the `on-message` proc is:

    proc on-message {chan message} {
        ...
    }

Similarly, when a connection is established or closed the following procedures are called respectively:

    proc on-connect {chan} {
    }

    proc on-close {chan} {
    }

To run a server with this dispatcher just call: 

    Websocket::start 1337


## Default JSON-RPC implementation

Another default dispatcher that is delivered through this package is the `jsonrpc` space that:

* accepts json input and translates it into a tcl data structure
* reads the 'action' attribute and forwards it to a proc `on-message` in the `Action::$action` namespace. 

The proc has the following signature:

    proc on-message {chan json} {
    }

Where json is a TCL datastructure. A simple sample echo action that also notifies others about incoming messages is the following code:

    namespace eval Action::echo {

        #
        #   Notify others about getting a message
        #
        proc notify-others {chan} {
            set output(message) [j' "hey guys! $chan here, just got a message!"]
            Websocket::broadcast $chan [json::encode [json::array output]]

            # -- or if you want to include the current chan in the response
            # Websocket::broadcast $chan [json::encode [json::array output]] 0

        }

        proc on-message {chan json} {
            set in_msg [dict get $json msg]

            set output(status) [ j' "ok" ]
            set output(message) [ j' "echo: $chan, $in_msg" ]

            notify-others $chan
     
            return [array get output]
        }
    }

The jsonrpc implementation has a mechanism that allows you to hook namespaces into `on-connect` and `on-close` events. 

    namespace eval Disconnect::notify-others {

        jsonrpc'has-on-close-callback

        proc on-close {chan} {      
            set leave(msg) [j' "$chan left for greener pastures"]
            Websocket::broadcast $chan [json::encode [json::array leave]]
        }

    }

    namespace eval Startup::initial-data {

        jsonrpc'has-on-connect-callback

        #
        #   This proc is called when a new connection is made
        #
        proc on-connect {chan} {
            set welcome(msg) [j' "welcome to this wonderful application"]
            Websocket::send-message $chan [json::encode [json::array welcome]]
        }

    }

Like so.

## Encoding a json response

TCL being a type-less language without very straight-forward ways of detecting the type of information that is being represented by a specific string (dict, list or value), an JSON encoder is wrapped in this package as well. To create a simple JSON result string, do the following:

    set output(status) [ j' "ok" ]
    set output(message) [ j' "echo" ]
    set output(list_of_values) [j' [list [j' 10] [j' 20] [j' 30]]]

    puts [json::encode [json::array output]]

## Messagebus

There is a messagebus you can use to send messages to channels that are subscribed to certain topics. 

To add a channel to a topic:

    Messagebus::subscribe $chan "your topic"

To unsubscribe:

    Messagebus::unsubcribe $chan "your topic"

To notify everyone in a topic with a certain message:

    Messagebus::notify "your topic" ".. json message .."

## Observables

Oftentimes you will want to keep people up-to-date on changes in a datastructure. This could be accomplished by using the messagebus to notify a topic with a certain message when information changes. There is also the 'observable' mechanism that wraps the messagebus slightly. 

To subscribe a channel to listen to updates to certain elements run:

    Observable::subscribe $chan userlist 

To unsubscribe:

    Observable::unsubscribe $chan userlist

Now, you can wrap operations on your datastructure with the `||` operator. It's supposed to be cool ASCII-art for a "data pipe". To listen to updates to our userlist do the following:

    || {userlist->list} {
        lappend userlist "another user"
    }

The `||` method checks the initial value, executes the body, checks the value after, if it has changed, it will push the userlist through a method in the Observable namespace called `convert-list`. This should return a valid json string that represents the datastructure. 

Which is then wrapped in a message that is sent to the `obs.userlist` channel (your javascript should be listening on this). 

The list conversion is the default, so shorthand for this would be:

    || {userlist} { .. }

If you have other structures that need to be changed, just add a proc to the `Observable` namespace with its only parameter being the value that is to be converted.

If userlist doesn't change, nothing is sent.
