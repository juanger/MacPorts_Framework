package require macports
package require simplelog



#Set ui_options to log all messages to stdout and notify system
#filtering is done on the Obj-C side of things
set ui_options(ports_debug) "yes"
set ui_options(ports_verbose) "yes"

# ui_options accessor
proc ui_isset {val} {
	global ui_options
	if {[info exists ui_options($val)]} {
		if {$ui_options($val) == "yes"} {
			return 1
		}
	}
	return 0
}

# UI Callback
proc ui_prefix {priority} {
    switch $priority {
        debug {
        	return "DEBUG: "
        }
        error {
        	return "Error: "
        }
        warn {
        	return "Warning: "
        }
        default {
        	return ""
        }
    }
}

proc ui_channels {priority} {
    global logfd
    switch $priority {
        debug {
            if {[ui_isset ports_debug]} {
            	return {stderr}
            } else {
            	return {}
            }
        }
        info {
            if {[ui_isset ports_verbose]} {
                return {stdout}
            } else {
                return {}
			}
		}
        msg {
            if {[ui_isset ports_quiet]} {
                return {}
			} else {
				return {stdout}
			}
		}
        error {
        	return {stderr}
        }
        default {
        	return {stdout}
        }
    }
}



#Modifying UI initialization to enable notifications
#Redefine ui_$pritority to throw global notifications
#This is currently under works ... a reasonable solution
#should be coming up soon
proc macports::ui_init {priority args} {
    switch $priority {
  		msg {
  			set nottype "MPMsgNotification" 
  		}
  		debug {
  			set nottype "MPDebugNotification"
  			puts "Recieved Debug"
  		}
  		warn {
  			set nottype "MPWarnNotification"
  		}
  		error {
  			set nottype "MPErrorNotification"
  			puts "Recieved Error"
  		}
  		info {
  			set nottype "MPInfoNotification"
  			puts "Recieved Info"
  		}
  		default {
  			set nottype "MPDefaultNotification"
  		}	
  	}
  
    # Get the list of channels.
    if {[llength [info commands ui_channels]] > 0} {
        set channels [ui_channels $priority]
    } else {
        set channels [ui_channels_default $priority]
    }

    # Simplify ui_$priority.
    set nbchans [llength $channels]
    if {$nbchans == 0} {
        proc ::ui_$priority {args} [subst {
          simplelog "$nottype $chan $prefix" "\$str"
        }]
    } else {
        if {[llength [info commands ui_prefix]] > 0} {
            set prefix [ui_prefix $priority]
        } else {
            set prefix [ui_prefix_default $priority]
        }

        if {[llength [info commands ::ui_init]] > 0} {
            eval ::ui_init $priority $prefix $channels $args
        } else {
            if {$nbchans == 1} {
                set chan [lindex $channels 0]
                proc ::ui_$priority {args} [subst {
                  if {\[lindex \$args 0\] == "-nonewline"} {
                    puts $chan "$prefix\[lindex \$args 1\]"
                    simplelog "$nottype $chan $prefix" "\[lindex \$args 1\]"
                  } else {
                    puts -nonewline $chan "$prefix\[lindex \$args 1\]"
                    simplelog "$nottype $chan $prefix" "\[lindex \$args 0\]"
                  }
                }]
            } else {
                proc ::ui_$priority {args} [subst {
                    foreach chan \$channels {
                      if {\[lindex \$args 0\] == "-nonewline"} {
                        puts $chan "$prefix\[lindex \$args 1\]"
                        simplelog "$nottype $chan $prefix" "\[lindex \$args 1\]"
                      } else {
                        puts -nonewline $chan "$prefix\[lindex \$args 1\]"
                        simplelog "$nottype $chan $prefix" "\[lindex \$args 0\]"
                      }
                    }
                }]
            }
        }

        # Call ui_$priority
        eval ::ui_$priority $args
    }
}


#Wrapping the following API routines to catch errors
#and log error Information in a similar fashion to code
#in macports.tcl. Note optionslist is not being used for now
set mp_empty_list [list]
proc mportuninstall {portname {v ""} {optionslist ""} } {
	if {[catch {portuninstall::uninstall $portname $v [array get options]} result]} {
		
			global errorInfo
			ui_debug "$errorInfo"
			ui_error "Uninstall $portname $v failed: $result"
			return 1
	}
}

proc mportactivate {portname {v ""} {optionslist ""}} {
	if {[catch {portimage::activate $portname $v $optionslist} result]} {
			
			global errorInfo
			ui_debug "$errorInfo"
			ui_error "Activate $portname $v failed: $result"
			return 1
	}
}

proc mportdeactivate {portname {v ""} {optionslist ""} } {
	if {[catch {portimage::deactivate $portname $v $optionslist} result]} {
			
			global errorInfo
			ui_debug "$errorInfo"
			ui_error "Deactivate $portname $v failed: $result"
			return 1
	}
}

proc mportupgrade {portname} {
    array set depscache {}
	if {[catch {macports::upgrade $portname "port:$portname" [array get global_variations] [array get variations] [array get options] depscache} result]} {
			
			global errorInfo
			ui_debug "$errorInfo"
			ui_error "Upgrade $portname failed: $result"
			return 1
	}
}

# Initialize dport
# This must be done following parse of global options, as some options are
# evaluated by dportinit.
if {[catch {mportinit ui_options global_options global_variations} result]} {
	global errorInfo
	puts "$errorInfo"
	fatal "Failed to initialize ports system, $result"
}