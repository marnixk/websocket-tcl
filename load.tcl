package provide websockets 1.0

package require log

set pkg_path [file dirname [info script]]

source "$pkg_path/json.tcl"
source "$pkg_path/websocket.tcl"
source "$pkg_path/messagedispatcher.tcl"
source "$pkg_path/jsonrpc-space.tcl"
source "$pkg_path/messagebus.tcl"
source "$pkg_path/observable.tcl"
