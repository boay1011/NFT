package require inifile

namespace eval config {
    variable Default
    variable Config
    variable UserConfigFile
}

proc config::change_user_config {conf_file} {
    variable UserConfigFile
    set UserConfigFile $conf_file
}

proc config::default {} {
    global RootDir
    variable Default
    
    set conf_file [file join [file dirname [info script]] "default.conf"]
    
    if { ![file exist $conf_file]} {
        ::error::error "$conf_file does not exist."
        return
    }
    
    set handle [::ini::open $conf_file r]

    foreach section [::ini::sections $handle] {
        foreach key [::ini::keys $handle $section] {
            set Default($key) [::ini::value $handle $section $key]
        }
    }

    ::ini::close $handle
}

proc config::load {} {
    variable Config
    variable Default
    variable UserConfigFile
    
    if { ![file exist $UserConfigFile]} {
        return
    }
        
    set handle [::ini::open $UserConfigFile]
    
    array set Config [array get Default]
    
    foreach section [::ini::sections $handle] {
        foreach key [::ini::keys $handle $section] {
            set Config($key) [::ini::value $handle $section $key]
        }
    }

    ::ini::close $handle
}

proc config::save {args} {
    variable Config
    variable UserConfigFile
   
    if { ![file exist $UserConfigFile]} {
        catch {close [open $UserConfigFile w]}
    }
    
    set handle [::ini::open $UserConfigFile]
    
    foreach key [array names Config] {
        ::ini::set $handle "Main" $key $Config($key)
    }
    
    catch {::ini::commit $handle}
    catch {::ini::close $handle}
}