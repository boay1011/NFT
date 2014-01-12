set RootDir [pwd]

package require registry
set key {HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders}
if {![catch {registry get $key AppData} dir]} {
set RootDir [file join $dir NFT]
}

package require msgcat

::msgcat::mcload [file join [file dirname [info script]] msgs]

lappend auto_path [file join $RootDir lib]

source [file join [file dirname [info script]] hook.tcl]

source [file join [file dirname [info script]] initial.tcl]
source [file join [file dirname [info script]] error.tcl]
source [file join [file dirname [info script]] config.tcl]

::config::default
::config::change_user_config [file join $RootDir "NFT.ini"]
::config::load

source [file join [file dirname [info script]] chat.tcl]
source [file join [file dirname [info script]] planet.tcl]
source [file join [file dirname [info script]] ui.tcl]
source [file join [file dirname [info script]] taskbar.tcl]
source [file join [file dirname [info script]] emoticons.tcl]
source [file join [file dirname [info script]] sound.tcl]

::ui::create

::hook::run finload

wm protocol . WM_DELETE_WINDOW {
    if {[tk_messageBox \
                -icon    question \
                -type    yesno \
                -default no \
                -message [::msgcat::mc "Do you want to go?"] \
                -title   [::msgcat::mc "Quit Application?"]] == "yes"} {
        ::ui::exit
    }
}