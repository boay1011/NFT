namespace eval hook {}

proc hook::add {hook func {seq 50}} {
    variable $hook

    lappend $hook [list $func $seq]
    set $hook [lsort -real -index 1 [lsort -unique [set $hook]]]
}

proc hook::remove {hook func {seq 50}} {
    variable $hook

    set idx [lsearch -exact [set $hook] [list $func $seq]]
    set $hook [lreplace [set $hook] $idx $idx]
}

proc hook::is_empty {hook} {
    variable $hook

    if {![info exists $hook] || [llength [set $hook]] == 0} {
        return 1
    } else {
        return 0
    }
}

proc hook::set_flag {hook flag} {
    variable F
    set idx [lsearch -exact $F(flags,$hook) $flag]
    set F(flags,$hook) [lreplace $F(flags,$hook) $idx $idx]
}

proc hook::unset_flag {hook flag} {
    variable F
    if {[lsearch -exact $F(flags,$hook) $flag] < 0} {
        lappend F(flags,$hook) $flag
    }
}

proc hook::is_flag {hook flag} {
    variable F
    return [expr {[lsearch -exact $F(flags,$hook) $flag] < 0}]
}

proc hook::run {hook args} {
    variable F
    variable $hook

    if {![info exists $hook]} {
        return
    }

    set F(flags,$hook) {}

    foreach func_prio [set $hook] {
        set func [lindex $func_prio 0]
        set code [catch { eval $func $args } state]

        if {$code == 3 || ($code == 0 && [string equal $state stop])} {
            break
        } elseif {$code == 1} {
            puts "ERROR: $state\n$func ($args)\n$hook"
        }
    }
}