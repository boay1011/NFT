set local [file join [file dirname [info script]] app_data]

cd $local

catch { file copy -force images [file join $RootDir images] }

catch { file copy NFT.ini [file join $RootDir NFT.ini] }
catch { file copy -force tclkit.ico [file join $RootDir tclkit.ico] }


cd [file dirname [info script]]