package require chatwidget
package require irc

rename socket socket_old
proc socket {args} {
    if {[lsearch $args "-async"] == -1} {
    set args [concat "-async" $args]
    }
    
    eval socket_old $args
}

namespace eval chat {
    variable Chat
    variable xlib
    variable UsedColors {}
    
    if { [catch {eval font create FONT $::config::Config(Font)}]} {
    font create FONT -size 10
    font create FONTbold -size 10
    } else {
    eval font create FONTbold $::config::Config(Font)
    }
    font configure FONTbold -weight bold
     
    set Chat(nick) $::config::Config(Nick)
    
    if {$Chat(nick) eq "RANDOM"} {
    set Chat(nick) "nft_user[expr {round(rand()*9999)}]"
    }
    
    set Chat(channel) $config::Config(Channel)
    set Chat(server) $config::Config(Server)
    
    set xlib [::irc::connection]
    
    if {$::config::Config(DisableChat)} {
        ::hook::add finload {.main.nb hide .main.nb.chat}
    }
    
    $xlib config debug 0
    
    event add <<Cut>>   <Control-division>
    event add <<Copy>>  <Control-ntilde>
    event add <<Paste>> <Control-igrave>
    event add <<Undo>>  <Control-ydiaeresis>
    event add <<Redo>>  <Control-ssharp>
    
    set ::connecting_time 5000
}

proc chat::create {} {
    variable Chat
    
    ::chatwidget::chatwidget .main.nb.chat
    
    .main.nb.chat message [::msgcat::mc "Welcome to Need For Talk!"] -type system
    
    .main.nb insert end .main.nb.chat -text [::msgcat::mc "Chat"] -image img/chat -compound left
    
    set Chat(chat) .main.nb.chat
    
    $Chat(chat) configure -font FONT
    
    ::hook::run chat_created
    
    .main.nb.chat hook add message [list ::chat::nmsg .main.nb.chat {}]
    
    bind .main.nb <<NotebookTabChanged>> ::chat::tab_changed
    bind TNotebook <3> {::chat::notebook_click %x %y %X %Y %W}
    
    [$chat::Chat(chat) chat] tag configure HIGHLIGHT -background grey
}

proc chat::notebook_click {x y X Y w} {
    set index [$w index @$x,$y]
    
    if {$index eq {}} {
    return
    }
  
    if {[.main.nb tab $index -text] eq [::msgcat::mc "Planet"] || \
        [.main.nb tab $index -text] eq [::msgcat::mc "Chat"]} {
            return
    }
  
    set m .tab_menu
    if {[winfo exist $m]} {
    destroy $m
    }
    
    menu $m -tearoff 0
    
    $m add command -label [::msgcat::mc "Close"] -command [list ::chat::close_tab $w $index]
    
    $m post $X $Y
}

proc chat::close_tab {w index} {
    variable Privates
    
    set who [.main.nb tab $index -text]
    set tag [to_tag $who]
   
   $w hide $index
}

proc chat::tab_changed {} {
    set tab [.main.nb select]
    set text [.main.nb tab $tab -tex]
    
    if {$text eq [::msgcat::mc "Chat"]} {
    pane_map
    }
    
    while {[string range $text 0 1] eq {* }} {
    set text [string range $text 2 end]
    }
    
    .main.nb tab $tab -text $text
}

proc ::chat::disconnect {} {
    variable reconnecting
    variable xlib
    
    set reconnecting 0
    
    if {[catch {$xlib connected}]} {
        $::chat::Chat(chat) message [::msgcat::mc "Not connected"] -type system
        return
    }
    
    $xlib quit $::config::Config(QuitText)
    $xlib disconnect
    
    $::chat::Chat(chat) message [::msgcat::mc "Disconnected from network"] -type system
    foreach nick [.main.nb.chat name list] {
    .main.nb.chat name delete $nick
    }
}

proc chat::close {} {
    ::chat::disconnect
    
    .main.nb forget .main.nb.chat
}

proc chat::connect_l { {msg 1} } {
    variable xlib
    variable Chat
    variable Loop
    variable reconnecting
    
    if {$::config::Config(DisableChat)} {
     return
    }
    
    if {[info commands $xlib] == {}} {
    set xlib [irc::connection]
    }
    
    if { [$xlib connected] } {
        if {$msg} {
            $::chat::Chat(chat) message [::msgcat::mc "Already connected"] -type system
        }
        return
    }
    
    if {[catch { $xlib connect $::chat::Chat(server) } ]} {
        $::chat::Chat(chat) message [::msgcat::mc "Not connected"] -type system
        $::chat::Chat(chat) message [::msgcat::mc "Reconnecting after %s sec" [expr {$::connecting_time/1000}]] -type system
        after $::connecting_time {::hook::run disconnect}
        return
    }
    
    $xlib nick $Chat(nick)
    $xlib user need_for_talk need_for_talk need_for_talk "Need For Talk"
    $xlib join $Chat(channel)
    
    set reconnecting 1 
    
    set Loop 1
    
    ::hook::run connected
}

proc chat::send {msg} {
    variable xlib
    variable Chat

    switch -glob -- $msg {
        {/name *} - {/nick *} {
            set arg [string range $msg 6 end]
            if { [string length $arg] <= 1 } {
                $Chat(chat) message [::msgcat::mc "Usage: /nick <newnick>"] -type system
                return
            } else {
                $xlib nick $arg
                set Chat(nick) $arg
                set ::config::Config(Nick) $arg
                catch {::config::save}
                return
            }
        }
        {/quit*} - {/exit*} {
            set arg [string range $msg 6 end]
            if {$arg eq {}} {
            set arg $::config::Config(QuitText)
            }
            $xlib quit $arg
            $xlib disconnect
            $xlib destroy
            exit
        }
        {/me *} {
            set arg [string range $msg 4 end]
            if {$arg eq {}} {
                $Chat(chat) message [::msgcat::mc "Usage: /me <message>"] -type system
                return
            } else {
                $xlib send "PRIVMSG $Chat(channel) :\001ACTION $arg\001"
                $Chat(chat) message $arg -type action -nick $Chat(nick)
                return
            }
        }
        {/connect*} {
            $Chat(chat) message [::msgcat::mc "Connecting..."] -type system
            ::chat::connect_l
            return
        }
        {/help*} {
            $Chat(chat) message "/me <message>" -type system
            $Chat(chat) message "/connect" -type system
            $Chat(chat) message "/nick <nick>" -type system
            $Chat(chat) message "/quit <message>" -type system
            $Chat(chat) message "/clean" -type system
            $Chat(chat) message "/help" -type system
            return
        }
        {/clean} - {/clear} {
            ::chat::clear
            return
        }
        {/*} {
            $Chat(chat) message [::msgcat::mc "Invalid command name. Try /help"] -type system
            return
        }
    }
    
    foreach line [split $msg \n] {
        $xlib privmsg $Chat(channel) $line
        $Chat(chat) message $line -nick $Chat(nick)
    }
    
    ::emoticons::replace
    
    ::hook::run message_send
}

proc chat::clear {} {
    variable Chat
    
    [$Chat(chat) chat] configure -state normal
    [$Chat(chat) chat] delete 1.0 end
    [$Chat(chat) chat] configure -state disabled
}

proc chat::to_tag {text} {
    variable texttag
    variable tagtext
    
    if {[info exists texttag($text)]} {
        return $texttag($text)
    } else {
        regsub -all {[^[:alnum:]]+} $text {} prefix
        set tag $prefix[rand 1000000000]
        while {[info exists tagtext($tag)]} {
            set tag $prefix[rand 1000000000]
        }

        set texttag($text) $tag
        set tagtext($tag) $text

        return $tag
    }
}

proc chat::rand {num} {
    return [expr int(floor(rand()*$num))]
}

proc chat::from_tag {tag} {
    variable tagtext

    if {[info exists tagtext($tag)]} {
	return $tagtext($tag)
    } else {
	::error::error "Unknown tag $tag"
    }
}

proc chat::register_event {} {
    variable xlib
    variable Chat
    
    $xlib registerevent PRIVMSG {
        if [regexp {\001ACTION ([^\001]+)\001} [msg] -> action] {
			$::chat::Chat(chat) message $action -type action -nick [who]
             ::emoticons::replace
			return
		}
    
        if { [target] eq $::chat::Chat(channel) } {
            set tag {NULL}
            if {[string match *$::chat::Chat(nick)* [msg]]} {
                set tag HIGHLIGHT
            }
            if {$::config::Config(BeepOnMessageInGroupchat)} {
                beep::beep msg
            }
            $::chat::Chat(chat) message [msg] -nick [who] -tags $tag
            ::emoticons::replace
            return
        }
        
        set tag [::chat::to_tag [who]]
        set who [who]
        
        if {[info exist ::chat::Privates]} {
            if {[lsearch [array names ::chat::Privates] $tag] >= 0} {
                if { [.main.nb tab $::chat::Privates($tag) -state] eq "hidden" } {
                .main.nb select $::chat::Privates($tag)
                }
                $::chat::Privates($tag) message [msg] -nick [who]
                if {$::config::Config(BeepOnMessageInChat)} {
                    beep::beep h_msg
                }
                ::emoticons::replace
                return
            }
        }
        
        ::chatwidget::chatwidget .main.nb.chat$tag
        grid .main.nb.chat$tag -sticky news
        
        .main.nb insert end .main.nb.chat$tag -text [who] -image img/chat -compound left
        
        set ::chat::Privates($tag) .main.nb.chat$tag
        
        bind [$::chat::Privates($tag) entry] <3> {::chat::popup_menu_entry .menu_entry %X %Y %W}
        bind [$::chat::Privates($tag) chat] <3> {::chat::popup_menu .menu %X %Y %x %y %W}
        
        $::chat::Privates($tag) names hide
        $::chat::Privates($tag) topic hide
        
        $::chat::Privates($tag) message [msg] -nick [who]
        
        $::chat::Privates($tag) hook add post [list ::chat::send_p $::chat::Privates($tag) [who]]
        $::chat::Privates($tag) hook add message [list ::chat::nmsg $::chat::Privates($tag) [who]]
        
        if {$::config::Config(BeepOnMessageInChat)} {
        beep::beep h_msg
        }
        
        ::emoticons::replace
    }
    
    $xlib registerevent 353 {
        foreach user [lsort [msg]] {
            ::chat::add_name $user
        }
    }
    
    $xlib registerevent 332 {
        $::chat::Chat(chat) topic show
        regsub -all {[0-9]*} [msg] {} msg
        $::chat::Chat(chat) topic set $msg
    }
    
    $xlib registerevent TOPIC {
        $::chat::Chat(chat) topic show
        regsub -all {[0-9]*} [msg] {} msg
        $::chat::Chat(chat) topic set $msg
    }
    
    $xlib registerevent NICK {
    
        $::chat::Chat(chat) name delete [who]
        ::chat::add_name [msg]
        
        $::chat::Chat(chat) message [::msgcat::mc "%s is known as %s" [who] [msg]] -type system
        
        set tag [::chat::to_tag [who]]
        
        if {[info exist ::chat::Privates($tag)]} {
            set ntag [::chat::to_tag [msg]]
            set ::chat::Privates($ntag) $::chat::Privates($tag)
            
            $::chat::Privates($tag) message [::msgcat::mc "%s is known as %s" [who] [msg]] -type system
            
            $::chat::Privates($tag) hook remove post [list ::chat::send_p $::chat::Privates($tag) [who]]
            $::chat::Privates($tag) hook add post [list ::chat::send_p $::chat::Privates($ntag) [msg]]
            $::chat::Privates($tag) hook remove message [list ::chat::nmsg $::chat::Privates($tag) [who]]
            $::chat::Privates($tag) hook add message [list ::chat::nmsg $::chat::Privates($ntag) [who]]
            
            .main.nb tab $::chat::Privates($ntag) -text [msg]
            
            unset ::chat::Privates($tag)
        }
    }
    
    $xlib registerevent 404 {
        $::chat::Chat(chat) message [msg] -type system
    }
    
    $xlib registerevent JOIN {
        $::chat::Chat(chat) message [::msgcat::mc "%s has join %s" [who adress] [msg]] -type system
        ::chat::add_name [who]
        if {[who] eq $::chat::Chat(nick)} {
        chat::rename_if_random
        }
    }
    
    $xlib registerevent QUIT {
        $::chat::Chat(chat) message [::msgcat::mc "%s has quit %s" [who adress] [msg]] -type system
        $::chat::Chat(chat) name delete [who]
        if {[who] eq $::config::Config(Nick)} {
        ::chat::send "/nick $::config::Config(Nick)"
        }
    }
    
    $xlib registerevent PART {
        $::chat::Chat(chat) message [::msgcat::mc "%s has quit %s" [who adress] [msg]] -type system
        $::chat::Chat(chat) name delete [who]
        if {[who] eq $::config::Config(Nick)} {
        ::chat::send "/nick $::config::Config(Nick)"
        }
    }
    
    $xlib registerevent LEAVE {
        $::chat::Chat(chat) message [::msgcat::mc "%s has quit %s" [who adress] [msg]] -type system
        $::chat::Chat(chat) name delete [who]
        if {[who] eq $::config::Config(Nick)} {
        ::chat::send "/nick $::config::Config(Nick)"
        }
    }
    
    $xlib registerevent 471 {
        $::chat::Chat(chat) message [::msgcat::mc "Can't join %s, channel is full" $Chat(channel)] -type system
    }
    
    $xlib registerevent 473 {
        $::chat::Chat(chat) message [::msgcat::mc "Can't join %s, channel is invite-only" $Chat(channel)] -type system
    }
    
    $xlib registerevent 474 {
        $::chat::Chat(chat) message [::msgcat::mc "Can't join %s, you are banned" $Chat(channel)] -type system
    }
    
    $xlib registerevent 519 {
        $::chat::Chat(chat) message [msg] -type system
    }
    
    $xlib registerevent 520 {
        $::chat::Chat(chat) message [msg] -type system
    }
    
    $xlib registerevent 477 {
        $::chat::Chat(chat) message [msg] -type system
    }
   
   $xlib registerevent 478 {
        $::chat::Chat(chat) message [msgcat::mc "Ban list is full"] -type system
    }
        
    $xlib registerevent 311 {
       $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }
    
    $xlib registerevent 312 {
        $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }
    
    $xlib registerevent 313 {
       $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }
    
    $xlib registerevent 317 {
        $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }

    $xlib registerevent 703 {
        $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }
    
    $xlib registerevent 318 {
        $::chat::Chat(chat) message "WHOIS [who]: [msg]" -type system
    }
    
    $xlib registerevent 451 {
        $::chat::Chat(chat) message [::msgcat::mc "That nickname is already in use by another occupant"] -type system
        $::chat::Chat(chat) message [::msgcat::mc "Reconnect with another nickname"] -type system
        if {[regexp {nft_user[0-9]*} $::chat::Chat(nick)]} {
            set ::chat::Chat(nick) "nft_user[expr {round(rand()*9999)}]"
        } else {
            append ::chat::Chat(nick) "_"
            if {[string range $::chat::Chat(nick) end-5 end] == "_____"} {
            set ::chat::Chat(nick) "nft_user[expr {round(rand()*9999)}]"
            }
        }
        $::chat::xlib nick $::chat::Chat(nick)
        $::chat::xlib join $::chat::Chat(channel)
    }

    $Chat(chat) hook add post ::chat::send
}

proc chat::nmsg {tab who msg args} {
    variable Chat
    
    foreach {key val} $args {
        if {$key eq "-type" && $val eq "system"} {
        return
        }
    }
    
    if {[.main.nb select] eq $tab && [winfo viewable .]} {
    return
    }

    if {[string range [.main.nb tab $tab -tex] 0 1] ne {* }} {
    .main.nb tab $tab -text "* [.main.nb tab $tab -tex]"
    }
}

proc chat::send_p {chat who msg} {
    variable xlib
    variable Chat

    foreach line [split $msg \n] {
        $xlib privmsg $who $line
        $chat message $line -nick $Chat(nick)
    }
    
    ::emoticons::replace $chat
}

proc chat::add_name {user} {
   foreach ch {& @ %} {
        if {[string index $user 0] eq $ch} {
        set group [::msgcat::mc "Admin"]
        break
        } else {
        set group [::msgcat::mc "User"]
        }
    }
    
    $::chat::Chat(chat) name add $user -group $group -color [::chat::get_rnd_color]
    
    pane_map
}

proc chat::pane_map {} {
    set inner .main.nb.chat.outer.inner
    set names .main.nb.chat.outer.inner.names.text

    set font [$names cget -font]
    set pane_width {}
    
    set max 0
    foreach user [$::chat::Chat(chat) name list] {
        set x [font measure $font [subst $user]]
        lappend pane_width [expr {$x+30}]
        set pane_width [lsort -unique $pane_width]
        
        foreach ix $pane_width {
        if {$ix > $max} {set max $ix}
        }
    }
    
    if {$max == 0} {set max 150}
    bind $names <Map> [list ::chatwidget::PaneMap %W $inner -$max]
    
    update idletasks
    
    ::chatwidget::PaneMap $names $inner -$max
}

proc chat::bind_handle {} {
    [$::chat::Chat(chat) names] tag bind NICK <1> \
        {::chat::insert_user %x %y}
    [$::chat::Chat(chat) names] tag bind NICK <Any-Enter> \
        {::chat::mouse_on_nick 1}
    [$::chat::Chat(chat) names] tag bind NICK <Any-Leave> \
        {::chat::mouse_on_nick 0}
    [$::chat::Chat(chat) chat] tag bind URL <Any-Enter> \
        {::chat::mouse_on_url 1}
    [$::chat::Chat(chat) chat] tag bind URL <Any-Leave> \
        {::chat::mouse_on_url 0}
    [$::chat::Chat(chat) chat] tag bind URL <1> \
        {::chat::open_url_in_browser %x %y %W}    
    [$::chat::Chat(chat) names] tag bind NICK <3> \
        {::chat::roster_menu %x %y %X %Y %W}
        
    bind [$::chat::Chat(chat) chat] <<Copy>> [list tk_textCopy [$::chat::Chat(chat) names]]
    bind [$::chat::Chat(chat) chat] <<Paste>> [list tk_textPaste [$::chat::Chat(chat) names]]
}

proc chat::open_url_in_browser {x y w} {
   set range [$w tag prevrange URL "@$x,$y"]
    
    if {$range != ""} {
    set url [$w get {*}$range]
    }
   
    catch {eval exec [auto_execok start] [list $url] &}
}

proc chat::roster_menu {x y X Y w} { 
    set m $w.menu
    
    if {[winfo exist $m]} {
    destroy $m
    }
    
    menu $m -tearoff 0
    
    $m add command -label [::msgcat::mc "Private"] -command [list ::chat::open_private $x $y $X $Y $w]
    $m add separator
    $m add command -label [::msgcat::mc "Insert nick"] -command [list ::chat::insert_user $x $y]
    
    $m post $X $Y
}

proc chat::open_private {x y X Y w} {
    set tags [$w tag names "@$x,$y"]
    foreach tag $tags {
        if {[string match NICK-* $tag]} {
            set range [[$::chat::Chat(chat) names] tag ranges $tag]
            set name [[$::chat::Chat(chat) names] get {*}$range]
            set name [string range $name 0 end-1]
       }
   }
   set tag [::chat::to_tag $name]
   set who $name
        
    if {[info exist ::chat::Privates]} {
        if {[lsearch [array names ::chat::Privates] $tag] >= 0} {
            .main.nb select $::chat::Privates($tag)
            return
        }
    }
        
    ::chatwidget::chatwidget .main.nb.chat$tag
    grid .main.nb.chat$tag -sticky news
    
    .main.nb insert end .main.nb.chat$tag -text $who -image img/chat -compound left
    .main.nb select .main.nb.chat$tag
    
    set ::chat::Privates($tag) .main.nb.chat$tag
    
    $::chat::Privates($tag) names hide
    $::chat::Privates($tag) topic hide
    
    $::chat::Privates($tag) hook add post [list ::chat::send_p $::chat::Privates($tag) $who]
    $::chat::Privates($tag) hook add message [list ::chat::nmsg $::chat::Privates($tag) $who]
    
    after idle [list bind [$::chat::Privates($tag) entry] <3> [list ::chat::popup_menu_entry .menu_entry %X %Y %W]]
    after idle [list bind [$::chat::Privates($tag) chat] <3> [list ::chat::popup_menu .menu %X %Y %x %y %W]]
    
    [$::chat::Privates($tag) chat] tag bind URL <Any-Enter> \
        {::chat::mouse_on_url 1}
    [$::chat::Privates($tag) chat] tag bind URL <Any-Leave> \
        {::chat::mouse_on_url 0}
    [$::chat::Privates($tag) chat] tag bind URL <1> \
        {::chat::open_url_in_browser %x %y %W}    
        
    bind [$::chat::Privates($tag) chat] <<Copy>> [list tk_textCopy [$::chat::Chat(chat) names]]
    bind [$::chat::Privates($tag) chat] <<Paste>> [list tk_textPaste [$::chat::Chat(chat) names]]
}

proc chat::mouse_on_url {bool} {
    [$::chat::Chat(chat) chat] configure -cursor \
        [expr {$bool ? "hand2" : \
            [lindex [[$::chat::Chat(chat) names] configure -cursor] 3]}]
}

proc chat::mouse_on_nick {bool} {
	[$::chat::Chat(chat) names] configure -cursor \
        [expr {$bool ? "hand2" : \
            [lindex [[$::chat::Chat(chat) names] configure -cursor] 3]}]
}

proc chat::insert_user {x y} {
    set tags [[$::chat::Chat(chat) names] tag names "@$x,$y"]
    foreach tag $tags {
        if {[string match NICK-* $tag]} {
            set range [[$::chat::Chat(chat) names] tag ranges $tag]
            set name [[$::chat::Chat(chat) names] get {*}$range]
            set name [string range $name 0 end-1]
            foreach ch {~ & @ % +} {
                if {[string index $name 0] eq $ch} {
                    set name [string range $name 1 end]
                }
            }
            [$::chat::Chat(chat) entry] insert insert "$name: "
            after idle {focus -force [$::chat::Chat(chat) entry]}
        }
    }
}

proc chat::get_rnd_color {} {
    variable UsedColors
    
    if { ! $::config::Config(ColoredNickNames)} {
        return black
    }
    set colors {
    000000 00008B D2691E B8860B 
    006400 556B2F 2F4F4F 
    008000 CD5C5C 808000 6B8E23 
    D87093 800080 708090 D02090 
    FF4500 304040 506060 604040 
    604070 503080 904030 304090 
    309030 2F402F 801080 
    309090 505050
    }
    
    set cn -1
    while {$cn < 0} {
        set idx [expr {round(rand()*([llength $colors]-1))}]
        if {[lsearch $UsedColors $idx] >= 0} {
            if {[expr {round(rand()*1)}]} {
                set cn $idx
            }
        } else {
            set cn $idx
        }
    }
    
    lappend UsedColors $cn
    return #[lindex $colors $cn]
    # return [format #%06x [expr {int(rand() * 0xFFFFFF)}]]
}

proc chat::popup_menu_entry {m x y {entry -1}} {
    if {[winfo exist $m]} {
        destroy $m
    }
    
    menu $m -tearoff 0
    
    if {$entry == -1} {
        set entry [$::chat::Chat(chat) entry]
    }
    
    $m add command -label [::msgcat::mc "Cut"] -command [list tk_textCut $entry] -accelerator Ctrl-X
    $m add command -label [::msgcat::mc "Copy"] -command [list  tk_textCopy $entry] -accelerator Ctrl-C
    $m add command -label [::msgcat::mc "Paste"] -command [list tk_textPaste $entry] -accelerator Ctrl-V
    
    $m add separator
    
    ::hook::run menu_chat_entry $m $entry
    
    $m post $x $y
}

proc chat::popup_menu {m X Y x y {w -1}} {
    if {[winfo exist $m]} {
        destroy $m
    }
    
    menu $m -tearoff 0
    
    if {$w == -1} {
        set w [$::chat::Chat(chat) chat]
    }
    
    set range [$w tag prevrange URL "@$x,$y"]
    
    if {$range != ""} {
        set url [$w get {*}$range]
        $m add command -label [::msgcat::mc "Open URL"] -command [list chat::open_url_in_browser $x $y $w]
        $m add command -label [::msgcat::mc "Copy URL"] -command [list chat::copy_url $w $url]
        $m add separator
    }
    
    $m add command -label [::msgcat::mc "Copy"] -command [list tk_textCopy $w]
    
    ::hook::run menu_chat $m $w
    
    $m post $X $Y
}

proc chat::copy_url {w url} {
    clipboard clear -displayof $w
    clipboard append -displayof $w $url
}

proc chat::connected_loop {} {
    variable xlib
    variable Chat
    variable Loop
    variable reconnecting

    if {[info exist reconnecting] && $reconnecting} {
        if {! [$xlib connected] && [info exist Loop] && $Loop} {
            $Chat(chat) message [::msgcat::mc "Disconnected from network"] \
                -type system
            set ::connecting_time 5000
            foreach nick [.main.nb.chat name list] {
                .main.nb.chat name delete $nick
            }
            ::hook::run disconnect
            set Loop 0
        }
    }
    
    if {[winfo viewable .]} {
        foreach tab [.main.nb tabs] {
            if {[.main.nb select] eq $tab} {
                set text [.main.nb tab $tab -text]
                if {[string index $text 0] == "*"} {
                .main.nb tab $tab -text [string range $text 2 end]
                }
            }
        }
    }
    
    set unreaded 0
    foreach tab [.main.nb tabs] {
        set text [.main.nb tab .main.nb.chat -text]
        if {[string index $text 0] == "*"} {
            set unreaded 1
        }
    }
    
    set text [wm title .]
    if {$unreaded} {
        if {[string index $text 0] != "*"} {
            wm title . "* $text"
            taskbar::unread
        }
    } else {
        if {[string index $text 0] == "*"} {
            set ntext [string range $text 2 end]
            wm title . $ntext
            taskbar::normal
        }
    }
    
    after idle [list after 1000 ::chat::connected_loop]
}

proc chat::beep {type} {
    switch $type {
        connect {::beep::beep conn}
        disconnect {::beep::beep discon}
    }
}

proc chat::rename {} {
    set name [::chat::rename_dialog [::msgcat::mc "Entry a new name ..."]]
    if {$name ne "" && $name ne "@"} {
    ::chat::send "/nick $name"
    }
}

proc chat::rename_dialog {text} {
    variable choise "@"
    
    toplevel .dialog
    
    wm attributes .dialog -topmost 1 -alpha 0.9 -toolwindow 1
    wm title .dialog [::msgcat::mc "Enter a new name ..."]
    
    ::ttk::frame .dialog.frame -relief flat -borderwidth 0
    
    ::ttk::label .dialog.frame.text -text $text -font FONT
    ::ttk::entry .dialog.frame.entry
    
    ::ttk::button .dialog.frame.ok -text "Ok" -command ::chat::nick_choised 
    ::ttk::button .dialog.frame.cancel -text [::msgcat::mc "Cancel"] -command [list set ::chat::choise @]
    
    grid .dialog.frame -padx 5 -pady 5 -sticky news

    grid .dialog.frame.text -row 0 -column 0 -columnspan 2 -sticky we -padx 3 -pady 3
    grid .dialog.frame.entry -row 1 -column 0 -columnspan 2 -sticky we -pady 5 -padx 5
    
    grid .dialog.frame.ok -row 2 -column 0 -sticky we -padx 3 -pady 3
    grid .dialog.frame.cancel -row 2 -column 1 -sticky we -padx 3 -pady 3
    
    update idletasks
    
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .dialog] / 2}]
    set y [expr {[winfo screenheight .] / 2 - [winfo reqheight .dialog] / 2}]
    
    wm geometry .dialog +$x+$y
    
    vwait ::chat::choise
    
    destroy .dialog
    
    focus -force .
    
    return $choise
}

proc chat::nick_choised {} {
    update idletasks
    set ::chat::choise [.dialog.frame.entry get]
}

proc chat::rename_if_random {} {
    if {[regexp {nft_user[0-9]*} $::chat::Chat(nick)]} {
        wm state . withdraw
        set nick [rename_dialog [::msgcat::mc "You'r name is undefined, please enter a new name"]]
        if {$nick ne "" && $nick ne "@"} {
        ::chat::send "/nick $nick"
        }
        wm state . normal
    }
}

::hook::add connected chat::connected_loop

::hook::add finload { bind [$::chat::Chat(chat) entry] <3> {::chat::popup_menu_entry .menu_entry %X %Y} }
::hook::add finload { bind [$::chat::Chat(chat) chat] <3> {::chat::popup_menu .menu %X %Y %x %y} }

::hook::add chat_create ::chat::create
::hook::add chat_created ::chat::register_event 5
::hook::add chat_created ::chat::bind_handle 15
::hook::add connected {::chat::beep connect} 100
::hook::add disconnect {::chat::beep disconnect} 100
::hook::add disconnect {::chat::connect_l 0} 50
::hook::add chat_created ::chat::pane_map 150
::hook::add chat_created ::chat::connect_l