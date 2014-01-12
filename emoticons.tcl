namespace eval emoticons {
    variable e_dir [file join  [file dirname [info script]] app_data emoticons]
    variable icondef_f [file join $e_dir _define]
}

proc ::emoticons::load {} {
    variable icondef_f
    variable e_dir
    variable emoticons
    variable emopics
    
    set fp [open $icondef_f r]
    set data [read $fp]
    close $fp

    set temp {}
    foreach line [split $data \n] {
    lappend temp $line
    }
    
    set idx 0
    foreach ff [lsort [glob -directory $e_dir *.gif]] {
        set f [file tail $ff]
        image create photo emotic/$f -file $ff
        foreach i [split [lindex $temp $idx] ,] {
            set emopics($f) $i
            set emoticons($i) emotic/$f
        }
        incr idx
    }
}

::hook::add finload ::emoticons::load 70

proc ::emoticons::replace {{chat -1}} {
    variable emoticons
    variable emopics
    
    if {!$::config::Config(UseEmoticons)} {
    return
    }
    
    if {$chat == -1} {
    set c $::chat::Chat(chat)
    } else {
    set c $chat
    }
    
    foreach em [array names emoticons] {
        set ixs [$c chat search "$em" end-2l]
        foreach idx $ixs {
            set len [string length $em]
            lassign [split $idx .] l r
            set lidx $l.[expr {$r+$len+1}]
            $c chat configure -state normal
            $c chat delete $idx $lidx
            $c chat image create $idx -image $emoticons($em)
            $c chat configure -state disabled
        }
    }
}

::hook::add message_send ::emoticons::replace 1

proc emoticons::insert_emotic {emotic entry} {
    $entry insert insert " $emotic "
    
    if {[winfo exist .emoticons]} {
    destroy .emoticons
    }
}

proc ::emoticons::dialog {entry} {
    variable emoticons
    variable emopics
    
    if {[winfo exist .emoticons]} {
    return
    }
    
    toplevel .emoticons
    wm overrideredirect .emoticons 1
    wm attributes .emoticons -alpha 0.85 -topmost 1
    
    bind .emoticons <3> [list destroy .emoticons]
    bind . <1> [list catch {destroy .emoticons}]
    
    set names {}
    set id 0
     foreach em [array names emopics] {
        ::ttk::label .emoticons.[incr id] -image emotic/$em
        bind .emoticons.$id <1> [list ::emoticons::insert_emotic $emopics($em) $entry]
        lappend names .emoticons.$id
     }
     
    set n [llength $names]
    set r [expr {round(sqrt($n))}]
    for {set i 0} {$i < $n} {incr i $r} {
        for {set x 0} {$x < $r} {incr x} {
            set p [lindex $names [expr $i + $x]]
            set c [expr {$i / $r}]
            if { ! [winfo exist $p]} {continue}
            grid $p -column $c -row $x -padx 2 -pady 2
        }
    }
    
    update idletasks
    
    set x [expr {[winfo screenwidth .]/2-[winfo width .emoticons] / 2}]
    set y [expr {[winfo screenheight .]/2-[winfo height .emoticons] / 2}]
    
    wm geometry .emoticons +$x+$y
}

proc emoticons::emotic_menu {m entry} {
    $m add command -label [::msgcat::mc "Emoticons"] -command [list ::emoticons::dialog $entry]
}

::hook::add menu_chat_entry ::emoticons::emotic_menu 5
::hook::add menu_private_entry ::emoticons::emotic_menu 5
