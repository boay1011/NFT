namespace eval error {}

proc error::error {msg} {
    tk_messageBox -message $msg \
        -icon "error" \
        -title "Fatal error"
}