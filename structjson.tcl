#
#	Encode a struct to json, this remedies the need to wrap all elements in their value type, instead
#	types are read from the struct definition. It allows the parsing of structs, values, lists and lists
#	with structs. 
#
module json {

	#
	#	Encode a struct
	#
	public encode-struct {struct} {

		set output "{"
		::array set struct_arr $struct
		set typename [struct-type $struct]
		set elements [struct-elements $typename]

		# how many elements are there?
		set n_elements [llength $elements]
		set current_element 0

		# iterate over each element
		foreach el $elements {

			set el_type [type-of $typename $el]

			set parsed_value [parse-type $el_type $el $struct_arr($el)]
			set output "$output $parsed_value"

			incr current_element
			if {$current_element != $n_elements} {
				set output "$output,"
			}
		}

		set output "$output}"

		return $output
	}

	#
	#
	#
	protected parse-type {type key value} {
		switch $type {
			"val" {
				return [struct-encode-value $key $value]
			}
			"list" {
				return [struct-encode-list $key $value]
			}
			"array" {
				return [struct-encode-array $key $value]
			}
			default {
				return "\"$key\" : [encode-struct $value]"
			}
		}		
	}

	#
	#	Encode a simple value
	#
	protected struct-encode-value {key value} {

		# is a type? render struct.
		if {[lsearch $value "_type"] > -1} then {
			return "\"$key\" : [encode-struct $value]"
		} else {
			return "\"$key\" : \"[encode-value $value]\""
		}

	}

	protected struct-encode-array {key array_list} {
		set output ""
		
		set n_elements [expr {[llength $array_list] / 2}]
		set current_element 0

		foreach {el_key el_val} $array_list {

			if {[lsearch $el_val "_type"] > -1} then {
				set output "$output \"$el_key\" : [encode-struct $el_val]"
			} else {
				set output "$output \"$el_key\" : \"[encode-value $el_val]\""
			}

			incr current_element
			if {$current_element != $n_elements} {
				set output "$output,"
			}
		}
		return "\"$key\" : {$output}"
	}

	#
	#	Encode a list
	#
	protected struct-encode-list {key list_of_values} {
		set output ""

		set n_elements [llength $list_of_values]
		set current_element 0
		foreach list_val $list_of_values {

			if {[lsearch $list_val "_type"] > -1} then {
				set output "$output [encode-struct $list_val]"
			} else {
				set output "$output \"[encode-value $list_val]\""
			}

			incr current_element
			if {$current_element != $n_elements} {
				set output "$output,"
			}
		}
		return "\"$key\" : \[$output\]"
	}

	protected encode-value {value} {
		set value [string map {"\"" "\\\"" } $value ]
		set value [string map {"\n" "\\n" } $value ]
		set value [string map {"\t" "\\t" } $value ]
		
		return $value
	}
}


# struct address {
# 	street val
# 	house_number val
# 	house_ext val
# 	phonenumber val
# 	mobilenumber {val "NA"}
# }

# struct person {
# 	name val
# 	age val
# 	listything list
# 	address address
# }

# set name "Example person"

# set p [create person { name $name age 29 }]
# set a [create address]

# person.address.street p "Example St."
# person.address.house_number p "135"
# person.address.house_ext p "GG"
# person.address.phonenumber p "09 1111212"
# person.listything p [list 10 20 $a $a $a $a]

# puts [json::encode-struct $p]