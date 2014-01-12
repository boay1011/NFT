package require sound

namespace eval beep {
    global RootDir
    variable Snd
    
    set Snd(msg) [::snack::sound -file [file join [file dirname [info script]] app_data sounds message.wav]]
    set Snd(h_msg) [::snack::sound -file [file join [file dirname [info script]] app_data sounds h_message.wav]]
    set Snd(conn) [::snack::sound -file [file join [file dirname [info script]] app_data sounds tada.wav]]
    set Snd(discon) [::snack::sound -file [file join  [file dirname [info script]] app_data sounds bird.wav]]
}

proc beep::beep {type} {
    variable Snd
    
    if {$::config::Config(DisableSounds)} {
    return
    }
    
    $Snd($type) play
}