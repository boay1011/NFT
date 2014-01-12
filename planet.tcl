package require http

namespace eval NFKPlanet {
    variable addr
    
    set addr(nplanet) {http://nfk.pro2d.ru/nplanet.php}
    set addr(nfk) {http://nfk.pro2d.ru}
    set addr(nfk_sock_server) {nfkplanet.pro2d.ru}
    set addr(nfk_sock_port) 10003
    set addr(part_for_players) {/api.php?action=server&name=}
    
    variable DB
    variable DBPlayers
    
    array set DB {}
    array set DBPlayers {}
    
    ::hook::add planet_create ::NFKPlanet::create 10
    ::hook::add finload NFKPlanet::get_planet_data 90
    ::hook::add new_player_on_planet ::NFKPlanet::new_player
    ::hook::add finload NFKPlanet::main_loop 100
}

proc NFKPlanet::create {} {
    global P
    
    set parent .main.nb
    
    ::ttk::frame $parent.planet
    
    grid rowconfigure $parent.planet 0 -weight 1
    grid columnconfigure $parent.planet 0 -weight 1
    
    $parent insert end $parent.planet -text [::msgcat::mc "Planet"] -image img/planet -compound left
    
    ::ttk::treeview $parent.planet.tree -columns {map type players ip} \
            -displaycolumns {map type players ip} \
            -yscroll "$parent.planet.vsb set"
 
    $parent.planet.tree heading #0 -text [::msgcat::mc "Server"]
    $parent.planet.tree heading map -text [::msgcat::mc "Map"]
    $parent.planet.tree heading type -text [::msgcat::mc "Game type"]
    $parent.planet.tree heading players -text [::msgcat::mc "Players"]
    $parent.planet.tree heading ip -text [::msgcat::mc "IP"]
    
    $parent.planet.tree column #0 -stretch 0 -width 200
    $parent.planet.tree column map -stretch 0 -width 100 -anchor center
    $parent.planet.tree column type -stretch 0 -width 100 -anchor center
    $parent.planet.tree column players -stretch 0 -width 100 -anchor center
    $parent.planet.tree column ip -stretch 0 -width 200 -anchor center
    
    ttk::scrollbar $parent.planet.vsb -orient vertical \
            -command "$parent.planet.tree yview"
   
    grid $parent.planet.tree $parent.planet.vsb \
        -sticky nsew -pady 5
    
    ::ttk::frame $parent.planet.buttons
    
    ::ttk::button $parent.planet.buttons.update -text [::msgcat::mc "Update"] -command NFKPlanet::get_planet_data
    ::ttk::button $parent.planet.buttons.join -text [::msgcat::mc "Join"] -command NFKPlanet::connect

    set P(show_hide_btn) $parent.planet.buttons.show_hide
    
    grid $parent.planet.buttons -sticky news -pady 5 -padx 5
    grid columnconfigure $parent.planet.buttons 0 -weight 1
    
    grid $parent.planet.buttons.join -column 1 -row 0 -sticky e -padx 5 -pady 5
    grid $parent.planet.buttons.update -column 0 -row 0 -sticky w -padx 5 -pady 5
    
    set P(tree) $parent.planet.tree
    
    ::ttk::frame $parent.planet.status
    ::ttk::label $parent.planet.status.status -font FONTbold
    
    grid $parent.planet.status -sticky e -pady 3 -padx 5
    grid $parent.planet.status.status -sticky e
    
    set P(status) $parent.planet.status.status
    
    $P(tree) tag configure font_tag -font FONT -anchor center
    $P(tree) tag configure font_bold_tag -font FONTbold
    $P(tree) tag configure Color:Normal -foreground #000000
    $P(tree) tag configure Color:Yellow -foreground #5da130
    $P(tree) tag configure Color:Red -foreground #800000
    
    bind $P(tree) <3> {::NFKPlanet::tree_menu %X %Y}
}

proc NFKPlanet::tree_menu {X Y} {
    set m .pl_menu
    if {[winfo exist $m]} {
    destroy $m
    }
    
    menu $m -tearoff 0
    
    $m add command -label [::msgcat::mc "Show all"] -command NFKPlanet::show_all_servers
    $m add command -label [::msgcat::mc "Hide all"] -command NFKPlanet::hide_all_servers
    $m add separator
    $m add command -label [::msgcat::mc "Update"] -command NFKPlanet::get_planet_data

    $m post $X $Y
}


proc NFKPlanet::FindNFKWindow {} {
    return 0
}

proc NFKPlanet::hide_all_servers {} {
    global P
    variable DB
    
    foreach server [array names DB] {
        set id [to_tag $server]
        $P(tree) item $id -open 0
    }
}

proc NFKPlanet::show_all_servers { {nofull 0} } {
    global P
    variable DB
    
    foreach server [array names DB] {
        set id [to_tag $server]
        if {$nofull} {
            set min [lindex [split [lindex $DB($server) 2] /] 0]
            set max [lindex [split [lindex $DB($server) 2] /] end]
            if {$min < $max && $min > 0} {
                $P(tree) item $id -open 1
            } else {
                $P(tree) item $id -open 0
            }
        } else {
            $P(tree) item $id -open 1
        }
    }
}

proc NFKPlanet::connect {} {
    variable as_spectator
    global P
    
    if { [$P(tree) selection] ne {} } {
        set item [$P(tree) selection]
        if {[$P(tree) parent [$P(tree) selection]] ne {}} {
        set item [$P(tree) parent [$P(tree) selection]]
        }
        set vals [$P(tree) item $item -values]
        set ip [lindex $vals end]
        set server [$P(tree) item $item -text]
    } else {
        set_status [::msgcat::mc "Select a server first"]
        return
    }
    
    if { [FindNFKWindow] } {
        tk_messageBox -message [::msgcat::mc "Need For Kill already runned"] \
            -title [::msgcat::mc "Error"] -icon error
        return
    }
    
    set choise [dialog $P(tree) $server]

    if {$choise == 0} return
   
    if {$choise == 1} {
    set as_spectator 1
    } else {
    set as_spectator 0
    }
    
    set vargs "+connect $ip"
    
    set game_dir $::config::Config(GameDir)
    if {![file exist $game_dir]} { 
        set key {HKEY_CLASSES_ROOT\nfk\shell\open\command}
        if { ! [catch { registry get $key {} }] } {
            set value [registry get $key {}]
            if { [regexp {(.+?)Launcher.+?} $value => path] } {
                if {![file exist $game_dir]} { 
                    set choise [::ui::yesno_dialog "Error" [::msgcat::mc "Please set a path to game. Try it now?"]]
                    if {$choise} {
                    ::ui::new_game_dir
                    }
                    return
                }
                set game_dir [file normalize $path]
            }
        }
    }
    
    set spec [file join $game_dir basenfk spectator.cfg]
    
    if {$as_spectator} {
        set local [file join [file dirname [info script]] app_data spectator.cfg]
        if {[catch {file copy -force $local $spec}]} {
        tk_messageBox -message [::msgcat::mc "Please set a path to game"] \
            -title "Error" -icon error -parent .
        return
        }
        append vargs " +exec spectator +nfkplanet"
    }
    
    set pe [file join $game_dir $::config::Config(LauncherFile)]

    if {$::config::Config(LauncherFile) eq {} || ![file exist $pe]} {
    set pe [file join $game_dir Launcher.exe]
    }
    
    if {$::config::Config(ManualArgs) ne ""} {
    append vargs " $::config::Config(ManualArgs)"
    }

    if {[catch { eval exec $pe $vargs & } result]} {
        tk_messageBox -message $result \
            -title "Error" -icon error
    }
}

proc NFKPlanet::clean {} {
    variable DB
    variable DBPlayers
    global P
    
    foreach server [array names DB] {
        set item [to_tag $server]
        $P(tree) delete $item
    }
    
    array unset DBPlayers
    array unset DB
}

proc NFKPlanet::add_line {server map type players ip} {
    global P
    variable DB
    
    lassign [split $players {/}] min max
    if {$min == 0} {
    set color_tag Color:Normal
    }
    if {$min < $max && $min > 0} {
    set color_tag Color:Yellow
    } 
    if {$min == $max || $min > $max} {
    set color_tag Color:Red
    } 
    
    catch {set id [$P(tree) insert {} end -id [to_tag $server] -text $server -tags [list font_tag $color_tag]]}
    
    catch {$P(tree) set $id map $map}
    catch {$P(tree) set $id type $type}
    catch {$P(tree) set $id players $players}
    catch {$P(tree) set $id ip $ip}

    set DB($server) [list $map $type $players $ip]
}

proc NFKPlanet::add_children_line {server children icon} {
    global P
    
    catch {$P(tree) insert [to_tag $server] end -text $children -image $icon -tags font_bold_tag}
}

proc NFKPlanet::set_status { text { auto_clean 1}  } {
    global P

    $P(status) configure -text $text
    
    if {$auto_clean} {
    after 6000 NFKPlanet::clear_status
    }
}

proc NFKPlanet::clear_status {} {
    global P
    
    $P(status) configure -text [::msgcat::mc "Idle"]
}

proc NFKPlanet::get_planet_data {} {
    variable DB
    variable DBPlayers
    variable DBPlayersLast
    
    if {[llength [chan names]] > 5} {
    return
    }
    
    array unset DBPlayersLast
    if {[llength [array get DBPlayers]] > 0} {
    array set DBPlayersLast [array get DBPlayers]
    }
    
    clean
    
    get_servers_from_sock
    
    set follow_servers 0
    foreach server [lsort [array names DB]] {
        eval {add_line $server} $DB($server)
        incr follow_servers
    }
    
    set_status [::msgcat::mc "Getting servers list done"]
    
    if {$follow_servers == 0} {
    set_status [::msgcat::mc "No servers follow"] 0
    set updating 0
    return
    }
    
    get_players_from_http
    
    foreach server [array names DBPlayers] {
        foreach elem $DBPlayers($server) {
        lassign $elem player icon
        add_children_line $server $player $icon
        }
    }
    
    diff_with_last_players
    show_all_servers 1  ;# No full
}

proc NFKPlanet::diff_with_last_players {} {
    variable DBPlayers
    variable DBPlayersLast
    
    if { ! [info exist DBPlayersLast] } {
    return
    }
    
    set n 0
    foreach server [array names DBPlayers] {
        foreach elem $DBPlayers($server) {
            lassign $elem player icon
            set finded 0
            foreach server_l [array names DBPlayersLast] {
                foreach elem $DBPlayersLast($server_l) {
                    lassign $elem player_n icon_n
                    if {$player eq $player_n} {
                    set finded 1
                    }
                }
            }
            if {$finded == 0} {
            lappend players $player
            lappend servers $server
            lappend icons $icon
            set n 1
            }
        }
    }
    
    if {$n} {::hook::run new_player_on_planet $players $servers $icons}
}

proc NFKPlanet::get_servers_from_sock {} {
    variable t_data
    variable DB
    variable addr
    
    if {[catch {set channel [socket -async $addr(nfk_sock_server) $addr(nfk_sock_port)]}]} {
    return
    }
    
    fconfigure $channel -blocking 0
    fileevent $channel readable [list NFKPlanet::get_servers_from_sock_process $channel]
    
    set_status [::msgcat::mc "Getting servers list ..."] 0
    
    set t_data {}
    set ::NFKPlanet::loop 0
    
    puts $channel "?V077"
    flush $channel
    
    after 10000 {set ::NFKPlanet::loop timeout}
    vwait ::NFKPlanet::loop
    if {$::NFKPlanet::loop eq "timeout"} return
    
    set idx 0
    set serv_idx 0
    array set temp {}
    foreach line [split $t_data \n] {
        if {$line eq " E" || $line eq "\n" || $line eq ""} {
        continue
        }
        regsub -all " L" $line "" line
        lappend temp($serv_idx) $line
        if {[incr idx] > 6} {
            set idx 0
            incr serv_idx
        }
    }
    
    foreach id [array names temp] {
        lassign $temp($id) ip server map type min max port
        regsub -all {\^[0-9]} $server {} server
        set type [string map {0 DM 2 TDM 3 CTF 4 RAIL 6 PRAC 7 DOM} $type]
        set players ${min}/${max}
        set ip ${ip}:${port}
        set server [string map [list "&nbsp;" " " "&gt;" ">" "&lt;" "<" "&amp;" "&"] $server]
        set DB($server) [list $map $type $players $ip]
    }
    
    set_status [::msgcat::mc "Server list getted"]
}

proc NFKPlanet::get_servers_from_sock_process {channel} {
    variable t_data
    
    if { [gets $channel result] >= 0 } {
        if { $result == "V077" } {
            puts $channel "?G"
            flush $channel
            return
        }
        
        if { $result eq { E} } {
            close $channel
            set ::NFKPlanet::loop 1
        }
        
        append t_data $result\n
    
    } else {
        if { [eof $channel] } {
            close $channel
            set ::NFKPlanet::loop 1
        }
    }
}

proc NFKPlanet::get_players_from_http {} {
    variable addr
    variable DB
    
    set_status [::msgcat::mc "Getging players list ..."] 0
    
    foreach server [array names DB] {
        set players [lindex $DB($server) 2]
        lassign [split $players {/}] min max
        if {$min == 0} continue
        set url "${addr(nfk)}${addr(part_for_players)}[http::formatQuery $server]"
        if {[catch {set token [::http::geturl $url \
                -command [list NFKPlanet::get_players_from_http_end $server]]
            }]} {
                return
        }
        ::http::wait $token
    }
    
    set_status [::msgcat::mc "Players list getted"]
}


proc NFKPlanet::get_players_from_http_end {server token} {
    variable DBPlayers
    variable addr
    
    set data [::http::data $token]
    set DBPlayers($server) {}
    
    if { ![regexp {<table .+?>(.*)</table>} $data NULL result]} {
    return 
    }
    
    regsub -all \t $result {} result
    regsub -all \n $result {} result
    
    regsub -all \{ $result \\\{ result
    regsub -all \} $result \\\} result
    
    set length 0
    set in_loop 1
        
    while {$in_loop} {
        set line [regexp -inline -start $length {<tr>.+?</tr>} $result]
        if {$line eq {}} {
            set in_loop 0
            break
        }
        
        if { [regexp {<tr><td>.+?<img src='.+?'.+?<img src='(.+?)'.+?<a href=.+?>(.+?)</a></td></tr>} \
                $line NULL icon_u nickname] } {
            lappend out [list $nickname $icon_u]
        } elseif { [regexp {<tr><td>[[:digit:]]</td><td>(.+?)</td></tr>} $line NULL nickname] } {
            lappend out [list $nickname {}]
        }
        
        incr length [expr [string length $line] - 5]
        unset line
    }

    global RootDir
    
    foreach line [lsort -unique $out] {
        lassign $line nickname player_u
        set icon_u {img/?}
        if {$player_u ne {}} {
            set u_p [lindex [split $player_u /] end]
            set i_f [file join $RootDir images $u_p]
            
            if { ! [file exist $i_f]} {
                set fp [open $i_f w]
                set token [::http::geturl $addr(nfk)$player_u -channel $fp]
                close $fp
                ::http::cleanup $token
            }
            
            set icon_u $u_p
            image create photo $u_p -file $i_f
        }
        
        regsub -all <font.+?> $nickname {} nickname
        regsub -all </font> $nickname {} nickname
        regsub -all \\\{ $nickname \{ nickname
        regsub -all \\\} $nickname \}nickname
        set nickname [string map [list {&nbsp;} { } {&gt;} {>} {&lt;} {<} {&amp;} {&}] $nickname]
        lappend DBPlayers($server) [list $nickname $icon_u]
    }
}

proc NFKPlanet::to_tag {text} {
    regsub -all {[^[:alnum:]]+} $text {} prefix
    return $prefix
}

proc NFKPlanet::dialog {parent server} {
    variable choise 0 
    
    toplevel .dialog
    
    wm attributes .dialog -topmost 1 -alpha 0.9 -toolwindow 1
    wm title .dialog [::msgcat::mc "Connecting to %s" $server]
    
    ::ttk::frame .dialog.frame -relief flat -borderwidth 0
    ::ttk::label .dialog.frame.text -text [::msgcat::mc "Join as ..."] -font FONT
    
    ::ttk::button .dialog.frame.spec -text [::msgcat::mc "Spectator"] -command "set ::NFKPlanet::choise 1"
    ::ttk::button .dialog.frame.play -text [::msgcat::mc "Player"] -command "set ::NFKPlanet::choise 2"
    ::ttk::button .dialog.frame.cancel -text [::msgcat::mc "Cancel"] -command "set ::NFKPlanet::choise 0"
    
    grid .dialog.frame -padx 5 -pady 5 -sticky news
    grid .dialog.frame.text -row 0 -columnspan 3 -sticky we -column 1
    grid .dialog.frame.spec .dialog.frame.play .dialog.frame.cancel -row 1 -sticky we -padx 3 -pady 2
    
    update idletasks
    
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .dialog] / 2}]
    set y [expr {[winfo screenheight .] / 2 - [winfo reqheight .dialog] / 2}]
    
    wm geometry .dialog +$x+$y
    
    vwait ::NFKPlanet::choise
    
    destroy .dialog
    
    focus -force $parent
    
    return $choise
}

proc NFKPlanet::new_player {players servers icons} {
    if { ! $::config::Config(Notify)} {
    return
    }
    
    if { [FindNFKWindow] } {
    return
    }
    
    if {[winfo exist .notify]} {
    destroy .notify
    }
    
    toplevel .notify
    
    wm withdraw .notify
    
    wm attributes .notify -topmost 1 -alpha 0.8
    wm overrideredirect .notify 1
    
    ::ttk::frame .notify.frame -relief flat -borderwidth 1
    grid .notify.frame -sticky news -padx 3 -pady 3
    
    ::ttk::label .notify.frame.text -text [::msgcat::mc "On NFK Planet now:"] -font FONTbold
    grid .notify.frame.text -sticky we -padx 2 -pady 3 -columnspan 2
    
    for {set i 0} {$i < [llength $players]} {incr i} {
        set r "[lindex $servers $i]:\t[lindex $players $i]"
        ::ttk::label .notify.frame.pl$i -text $r -font FONT -foreground darkred
        ::ttk::label .notify.frame.lab$i -image [lindex $icons $i]
        grid .notify.frame.lab$i -row [expr {$i + 1}] -column 0 -sticky we
        grid .notify.frame.pl$i -row [expr {$i + 1}] -column 1 -sticky w
        if {$i == 10} break
    }
    
    bind  .notify <1> {destroy .notify}

    wm state .notify normal
    
    update idletasks
    
    if {$::config::Config(NotifyPositionY) eq "up"} {
    set y 0
    } else {
    set y [expr {[winfo screenheight .] - [winfo reqheight .notify]}]
    }
    
    if {$::config::Config(NotifyPositionX) eq "right"} {
    set x [expr {[winfo screenwidth .] - [winfo reqwidth .notify]}]
    } else {
    set x 0
    }
    
    incr y $::config::Config(NotifyOffsetY)
    incr x $::config::Config(NotifyOffsetX)
    
    wm geometry .notify +$x+$y
    
    set time [expr {$::config::Config(NotifyTime) * 1000}]
    
   after $time { catch { destroy .notify } }
}

proc NFKPlanet::main_loop {} {
    variable last_time
    
    if {![info exist last_time]} {
    set last_time [clock seconds]
    }
        
    if {$::config::Config(AutoUpdate)} {
        set ut $::config::Config(AutoUpdateTime)
      
        if {$ut > 0 && ! [FindNFKWindow] } {
            if { [clock seconds] >= [expr {$last_time + $ut}] } {
                get_planet_data
                set last_time [clock seconds]
            }       
        }  
    }
    
    after 1000 NFKPlanet::main_loop
}