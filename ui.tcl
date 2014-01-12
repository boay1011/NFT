package require Ttk
package require Img
package require chatwidget
package require ttk::theme::keramik
package require ttk::theme::plastik
package require choosefont

namespace eval ui {
    global RootDir
    
    set dir [file join [file dirname [info script]] app_data]
    image create photo img/chat -file [file join $dir static chat.png]
    image create photo img/planet -file [file join $dir static earth.png]
    image create photo img/? -file [file join $dir static question.png]
    image create photo img/ico -file [file join [file dirname [info script]] taskbar.ico]
    image create photo img/ico_red -file [file join [file dirname [info script]] taskbar_red.ico]
    
    image create photo img/connect -file [file join $dir static connect.png]
    image create photo img/disconnect -file [file join $dir static disconnect.png]
    image create photo img/configuration -file [file join $dir static configuration.png]
    image create photo img/quit -file [file join $dir static quit.png]
    image create photo img/close -file [file join $dir static close.png]
    image create photo img/clear -file [file join $dir static clear.png]
    image create photo img/rename -file [file join $dir static rename.png]
    image create photo img/update -file [file join $dir static update.png]
    
    bind all <Key-F2> {console show}
    bind all <Key-F3> {console hide}
    
    trace add variable ::config::Config(AutoUpdate) write ::config::save
    trace add variable ::config::Config(Notify) write ::config::save
}

proc ui::create {} {
    wm title . "Need For Talk"
    wm iconphoto . img/ico
    
    menu .mb -type menubar
    ::hook::run create_menu .mb
    . configure -menu .mb
    
    ::ttk::frame .main
    ::ttk::notebook .main.nb
    ::ttk::frame .main.toolbar
    
    ::hook::run planet_create
    ::hook::run chat_create

    pack .main -fill both -expand yes
    pack .main.nb -fill both -expand yes -padx 5 -pady 5
    
    ::ttk::style theme use $::config::Config(Style)
}

proc ::ui::main_menu {m} {
    menu .mb_main -type normal -tearoff 0
    
    .mb_main add command -label [::msgcat::mc "Open Planet"] -command {.main.nb select .main.nb.planet} -image img/planet -compound left
    .mb_main add command -label [::msgcat::mc "Open Chat"] -command {.main.nb select .main.nb.chat} -image img/chat -compound left
    .mb_main add separator
    .mb_main add command -label [::msgcat::mc "Configuration"] -command ::ui::setting -image img/configuration -compound left
    .mb_main add separator
    .mb_main add command -label [::msgcat::mc "Quit"] -command ::ui::exit -image img/quit -compound left
    
    if { !$::config::Config(DisableChat)} {
    menu .mb_chat -type normal -tearoff 0
    .mb_chat add command -label [::msgcat::mc "Connect"] -command ::chat::connect_l -image img/connect -compound left
    .mb_chat add command -label [::msgcat::mc "Disconnect"] -command ::chat::disconnect -image img/disconnect -compound left
    .mb_chat add command -label [::msgcat::mc "Rename"] -command ::chat::rename -image img/rename -compound left
    .mb_chat add command -label [::msgcat::mc "Clear"] -command ::chat::clear -image img/clear -compound left
    .mb_chat add command -label [::msgcat::mc "Close"] -command ::chat::close -image img/close -compound left
    }
    
    menu .mb_planet -type normal -tearoff 0
    .mb_planet add command -label [::msgcat::mc "Update"] -command ::NFKPlanet::get_planet_data -image img/update -compound left
    .mb_planet add separator
    .mb_planet add checkbutton -label [::msgcat::mc "Auto update"] -variable ::config::Config(AutoUpdate)
    .mb_planet add checkbutton -label [::msgcat::mc "Notify window"] -variable ::config::Config(Notify)
    
    $m add cascade -menu .mb_main -label "NFT"
    
    if { !$::config::Config(DisableChat)} {
    $m add cascade -menu .mb_chat -label [::msgcat::mc "Chat"]
    }
    
    $m add cascade -menu .mb_planet -label [::msgcat::mc "Planet"]
}

proc ui::set_new_theme {theme} {
    ::ttk::style theme use $theme
    set ::config::Config(Style) $theme
    catch { ::config::save }
}

proc ui::exit {} {
    catch { $::chat::xlib quit $::config::Config(QuitText) }
    catch { $::chat::xlib destroy }
    catch {destroy $::taskbar::ico}
    catch {destroy $::taskbar::ico_red}
    destroy .
    exit
}

::hook::add create_menu ::ui::main_menu

proc ui::setting {} {
    
    catch {destroy .setting}
    
    toplevel .setting
    
    wm attributes .setting -toolwindow 1
    wm title .setting [::msgcat::mc "Settings"]
    
    ::ttk::frame .setting.frame -relief flat -borderwidth 0
    grid .setting.frame -padx 5 -pady 5
    
    ::ttk::label .setting.frame.font -text [::msgcat::mc "Font: "]
    set fam [font configure FONT -family]
    if {$fam == ""} {
    set fam "Default"
    }
    ::ttk::button .setting.frame.font_c -text $fam \
        -command ::ui::new_font
        
    grid .setting.frame.font -padx 5 -pady 5 -sticky news -column 0 -row 0
    grid .setting.frame.font_c -padx 5 -pady 5 -sticky news  -column 1 -row 0
    
    ::ttk::label .setting.frame.colored_nicks -text [::msgcat::mc "Colored nicknames: "]
    set bool [expr {$::config::Config(ColoredNickNames) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.colored_nicks_c -text $bool \
        -command ::ui::new_colored_nicknames
        
    grid .setting.frame.colored_nicks -padx 5 -pady 5 -sticky news -column 0 -row 1
    grid .setting.frame.colored_nicks_c -padx 5 -pady 5 -sticky news -column 1 -row 1
    
    ::ttk::label .setting.frame.nick -text [::msgcat::mc "You'r nickname: "]
    set n $::config::Config(Nick)
    if {$n eq "RANDOM"} {
    set n "Undefined"
    }
    ::ttk::button .setting.frame.nick_c -text $n \
        -command ::ui::new_nick
        
    grid .setting.frame.nick -padx 5 -pady 5 -sticky news -column 0 -row 2
    grid .setting.frame.nick_c -padx 5 -pady 5 -sticky news -column 1 -row 2
    
    ::ttk::label .setting.frame.beep_group -text [::msgcat::mc "Sound on message in groupchat: "]
    set bool [expr {$::config::Config(BeepOnMessageInGroupchat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.beep_group_c -text $bool \
        -command ::ui::new_beep_groupchat
        
    grid .setting.frame.beep_group -padx 5 -pady 5 -sticky news -column 0 -row 3
    grid .setting.frame.beep_group_c -padx 5 -pady 5 -sticky news -column 1 -row 3

    ::ttk::label .setting.frame.beep_chat -text [::msgcat::mc "Sound on message in chat: "]
    set bool [expr {$::config::Config(BeepOnMessageInChat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.beep_chat_c -text $bool \
        -command ::ui::new_beep_chat
        
    grid .setting.frame.beep_chat -padx 5 -pady 5 -sticky news -column 0 -row 4
    grid .setting.frame.beep_chat_c -padx 5 -pady 5 -sticky news -column 1 -row 4
    
    ::ttk::label .setting.frame.quit_text -text [::msgcat::mc "Quit message: "]
    ::ttk::button .setting.frame.quit_text_c -text $::config::Config(QuitText) \
        -command ::ui::new_quit_text

    grid .setting.frame.quit_text -padx 5 -pady 5 -sticky news -column 0 -row 5
    grid .setting.frame.quit_text_c -padx 5 -pady 5 -sticky news -column 1 -row 5

    ::ttk::separator .setting.frame.sep -orient vertical
    grid .setting.frame.sep -column 2 -row 0 -rowspan 6 -sticky news -padx 8
    
    ## Column 2
    ::ttk::label .setting.frame.style -text [::msgcat::mc "Interface stye: "]
    ::ttk::button .setting.frame.style_c -text [string totitle $::config::Config(Style)] \
        -command ::ui::new_style

    grid .setting.frame.style -padx 5 -pady 5 -sticky news -column 3 -row 0
    grid .setting.frame.style_c -padx 5 -pady 5 -sticky news -column 4 -row 0
    
    ::ttk::label .setting.frame.notify -text [::msgcat::mc "Notify window: "]
    set bool [expr {$::config::Config(Notify) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.notify_c -text $bool \
        -command ::ui::new_notify

    grid .setting.frame.notify -padx 5 -pady 5 -sticky news -column 3 -row 1
    grid .setting.frame.notify_c -padx 5 -pady 5 -sticky news -column 4  -row 1
    
    ::ttk::label .setting.frame.auto_update -text [::msgcat::mc "Auto update: "]
    set bool [expr {$::config::Config(AutoUpdate) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.auto_update_c -text $bool \
        -command ::ui::new_auto_update

    grid .setting.frame.auto_update -padx 5 -pady 5 -sticky news -column 3 -row 2
    grid .setting.frame.auto_update_c -padx 5 -pady 5 -sticky news -column 4  -row 2
    
    ::ttk::label .setting.frame.auto_update_time -text [::msgcat::mc "Auto update time: "]
    ::ttk::button .setting.frame.auto_update_time_c -text $::config::Config(AutoUpdateTime) \
        -command ::ui::new_auto_update_time

    grid .setting.frame.auto_update_time -padx 5 -pady 5 -sticky news -column 3 -row 3
    grid .setting.frame.auto_update_time_c -padx 5 -pady 5 -sticky news -column 4  -row 3
    
    set game_dir $::config::Config(GameDir)
    set key {HKEY_CLASSES_ROOT\nfk\shell\open\command}
    if { ! [catch { registry get $key {} }] } {
        set value [registry get $key {}]
        if { [regexp {(.+?)Launcher.+?} $value => path] } {
        set game_dir [file normalize $path]
        }
    }
    
    ::ttk::label .setting.frame.game_dir -text [::msgcat::mc "Game directory: "]
    ::ttk::button .setting.frame.game_dir_c -text $game_dir \
        -command ::ui::new_game_dir

    grid .setting.frame.game_dir -padx 5 -pady 5 -sticky news -column 3 -row 4
    grid .setting.frame.game_dir_c -padx 5 -pady 5 -sticky news -column 4 -row 4
    
     ::ttk::label .setting.frame.chat_disable -text [::msgcat::mc "Disable chat on startup: "]
    set bool [expr {$::config::Config(DisableChat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    ::ttk::button .setting.frame.chat_disable_c -text $bool \
        -command ::ui::new_chat_disable

    grid .setting.frame.chat_disable -padx 5 -pady 5 -sticky news -column 3 -row 5
    grid .setting.frame.chat_disable_c -padx 5 -pady 5 -sticky news -column 4 -row 5
    
    update idletasks
    
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .setting] / 2}]
    set y [expr {[winfo screenheight .] / 2 - [winfo reqheight .setting] / 2}]
    
    wm geometry .setting +$x+$y
}

proc ui::new_chat_disable {} {
    set choise [yesno_dialog [::msgcat::mc "Disable chat"] [::msgcat::mc "Disable chat when startup?"]]
    set ::config::Config(DisableChat) $choise
    ::config::save
    set bool [expr {$::config::Config(DisableChat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.chat_disable_c  configure -text $bool
}

proc ui::new_game_dir {} {
    set game_dir $::config::Config(GameDir)
    
    set dir [tk_chooseDirectory -initialdir $game_dir -title [::msgcat::mc "Choose a directory"]]
    puts $dir
    if {$dir ne ""} {
    set ::config::Config(GameDir) $dir
    ::config::save
    catch {.setting.frame.game_dir_c configure -text $dir}
    }

}

proc ui::new_auto_update_time {} {
    set res [::chat::rename_dialog [::msgcat::mc "Please enter new time"]]
    if {[string is integer $res] && $res != ""} {
        set ::config::Config(AutoUpdateTime) $res
        .setting.frame.auto_update_time_c  configure -text $res
    } else {
    tk_messageBox -message [::msgcat::mc "Incorrect value"] -title [::msgcat::mc "Error"] -icon error
    }
}

proc ui::new_auto_update {} {
    set choise [yesno_dialog [::msgcat::mc "Auto update"] [::msgcat::mc "Update automaticaly planet?"]]
    set ::config::Config(AutoUpdate) $choise
    ::config::save
    set bool [expr {$::config::Config(AutoUpdate) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.auto_update_c  configure -text $bool
}

proc ui::new_notify {} {
    set choise [yesno_dialog [::msgcat::mc "Notify"] [::msgcat::mc "Activate notify window (when new players on NFK Planet)?"]]
    set ::config::Config(Notify) $choise
    ::config::save
    set bool [expr {$::config::Config(Notify) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.notify_c  configure -text $bool
}

proc ui::new_style {} {
   variable choise
   variable listvar
   
   catch {destroy .style}
   
   toplevel .style
    
    wm attributes .style -topmost 1 -alpha 0.9 -toolwindow 1
    wm title .style [::msgcat::mc "Style"]
    
    ::ttk::frame .style.frame -relief flat -borderwidth 0
    ::ttk::label .style.frame.text -text [::msgcat::mc "Choise style"] -font FONT
    
    set listvar [::ttk::style theme names]
    
    listbox .style.frame.list -listvar ::ui::listvar -width 10 -bd 1 \
            -font FONT -selectmode single -exportselection 0
    
    ::ttk::button .style.frame.ok -text "Ok" -command ::ui::select_theme
    ::ttk::button .style.frame.cancel -text [::msgcat::mc "Cancel"] -command "set ::ui::choise {}"
    
    grid .style.frame -padx 5 -pady 5 -sticky news
    grid .style.frame.text -row 0 -sticky we
    grid .style.frame.list -row 1 -sticky news -padx 3 -pady 2
    grid .style.frame.ok -row 2 -sticky we -padx 3 -pady 3
    grid .style.frame.cancel -row 3 -sticky we -padx 3 -pady 3
    
    update idletasks
    
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .style] / 2}]
    set y [expr {[winfo screenheight .] / 2 - [winfo reqheight .style] / 2}]
    
    wm geometry .style +$x+$y
    
    bind .style.frame.list <<ListboxSelect>> ::ui::set_theme_process
    
    vwait ::ui::choise
    
    if {$::ui::choise != ""} {
    set_new_theme $::ui::choise
    }
}

proc ::ui::set_theme_process {} {
    set idx [.style.frame.list curselection]
    
    if { $idx != "" } {
    set theme [.style.frame.list get $idx]
    ::ttk::style theme use $theme
    }
}

proc ui::select_theme {} {
    set idx [.style.frame.list curselection]
    
    if { $idx != "" } {
    set ::ui::choise [.style.frame.list get $idx]
    } else {
    set ::ui::choise ""
    }
    
    destroy .style 
}

proc ui::new_quit_text {} {
    set text [::chat::rename_dialog [::msgcat::mc "Please enter message"]]
    if {$text ne ""} {
        set ::config::Config(QuitText) $text
        .setting.frame.quit_text_c  configure -text $text
    }
}

proc ui::new_beep_groupchat {} {
    set choise [yesno_dialog [::msgcat::mc "Sound on message" "Sound on message in groupchat?"]]
    set ::config::Config(BeepOnMessageInGroupchat) $choise
    ::config::save
    set bool [expr {$::config::Config(BeepOnMessageInGroupchat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.beep_group_c  configure -text $bool
}

proc ui::new_beep_chat {} {
    set choise [yesno_dialog [::msgcat::mc "Sound on message"] [::msgcat::mc "Sound on message in chat?"]]
    set ::config::Config(BeepOnMessageInChat) $choise
    ::config::save
    set bool [expr {$::config::Config(BeepOnMessageInChat) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.beep_chat_c  configure -text $bool
}

proc ui::new_nick {} {
        set nick [::chat::rename_dialog [::msgcat::mc "Please enter a new name"]]
        if {$nick ne "" && $nick ne "@"} {
            set ::config::Config(Nick) $nick
            ::chat::send "/nick $nick"
            set n $::config::Config(Nick)
            if {$n eq "RANDOM"} {
                set n "Undefined"
            }
            .setting.frame.nick_c  configure -text $n
        }
}

proc ui::new_font {} {
    set font_opts [choosefont::choosefont  \
            -font [list [font configure FONT -family] [font configure FONT -size]] \
            -title [::msgcat::mc "Choise a font"] -fonttype all]
            
    if {$font_opts == ""} {
    return
    }
    catch { font delete FONT }
    eval font create FONT $font_opts
    
    set ::config::Config(Font) $font_opts
    ::config::save
    
    catch { $::chat::Chat(chat) configure -font FONT }
    
    set fam [font configure FONT -family]
    if {$fam == ""} {
    set fam "Default"
    }
    .setting.frame.font_c configure -text $fam
}

proc ui::new_colored_nicknames {} {
    set choise [yesno_dialog [::msgcat::mc "Colored nicknames"] [::msgcat::mc "Use colored NickNames?"]]
    set ::config::Config(ColoredNickNames) $choise
    ::config::save
    set bool [expr {$::config::Config(ColoredNickNames) ? [::msgcat::mc "Yes"] : [::msgcat::mc "No"]}]
    .setting.frame.colored_nicks_c  configure -text $bool
    foreach nick [.main.nb.chat name list] {
    .main.nb.chat name delete $nick
    }
    $chat::xlib send "NAMES $::chat::Chat(channel)"
}

proc ui::yesno_dialog {title text} {
    variable choise ""
    
    toplevel .dialog
    
    wm attributes .dialog -topmost 1 -alpha 0.9 -toolwindow 1
    wm title .dialog $title
    
    ::ttk::frame .dialog.frame -relief flat -borderwidth 0
    ::ttk::label .dialog.frame.text -text $text -font FONT
    
    ::ttk::button .dialog.frame.yes -text [::msgcat::mc "Yes"] -command "set ::ui::choise 1"
    ::ttk::button .dialog.frame.no -text [::msgcat::mc "No"] -command "set ::ui::choise 0"
    
    grid .dialog.frame -padx 5 -pady 5 -sticky news
    grid .dialog.frame.text -row 0 -columnspan 2 -sticky we -column 0
    grid .dialog.frame.yes .dialog.frame.no -row 1 -sticky we -padx 3 -pady 2
    
    update idletasks
    
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .dialog] / 2}]
    set y [expr {[winfo screenheight .] / 2 - [winfo reqheight .dialog] / 2}]
    
    wm geometry .dialog +$x+$y
    
    vwait ::ui::choise
    
    destroy .dialog
    
    return $choise
}