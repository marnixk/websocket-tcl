
#
#   Adds typed encode functionality to json package namespace
#

namespace eval json {

	#
	#	Encode json struct
	#
	proc encode {struct} {
		set result ""
		foreach {type value} $struct {
			handle_type result $type $value
		}

		return $result
	}

	#
	#   Handle encountered type differently
	#
	proc handle_type {r_result type value} {
		upvar 1 $r_result result
		switch $type {
			array { handle_array result $type $value }			
			list { handle_list result $type $value }
			val { handle_value result $type $value }
		}
	}

	#
	#   Parse json map and append it to result
	#
	proc handle_array {r_result type value} {

		upvar 1 $r_result result

		append result "{ "

		set idx 0
		foreach {key child_desc} $value {
			set child_type [lindex $child_desc 0]
			set child_val [lindex $child_desc 1]

			append result "\"$key\" : "
			handle_type result $child_type $child_val

			if { $idx < [expr {([llength $value] / 2) - 1}] } then {
				append result ", "
			}
			incr idx
		}		
		append result " }"
	}

	#
	#   Parse json list and append it to result
	#
	proc handle_list {r_result type value} {

		upvar 1 $r_result result

		append result "\[ "

		set idx 0
		foreach child_desc $value {

			set child_type [lindex $child_desc 0]
			set child_val [lindex $child_desc 1]

			handle_type result $child_type $child_val
			if { $idx < [expr {[llength $value] - 1}] } then {
				append result ", "
			}
			incr idx
		}
		append result " \]"
	}

	#
	#	Parse json value and append it to result
	#
	proc handle_value {r_result type value} {
		upvar 1 $r_result result

		if {[string is integer $value]} then {
			append result $value
		} elseif {[string is boolean $value]} then {
			append result $value
		} else {
			append result "\"$value\""
		}

	}

	# ------------------------------------------------------------------
	# 
	# 				helpers to create tcl json structures
	# 
	# ------------------------------------------------------------------


	proc array {r_json_array} {
		upvar 1 $r_json_array json_array
		return [::list array [::array get json_array]]
	}

	proc list {json_list} {
		return [::list list $json_list]
	}

	proc value {value} {
		return [::list val $value]
	}

}

proc j' {value} {

	if {[string index $value 0] == "\{"} then {
		set first [lindex $value 0]
		if {[string index $first 0] == "\{"} then {
			return [json::array value]
		} else {
			return [json::list $value]
		}
	} else {
		return [json::value $value]
	}
}