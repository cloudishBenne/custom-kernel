# https://github.com/charmbracelet/vhs
# vhs custom-kernel.tape

Require custom-kernel

Sleep 1s
Type "sudo custom-kernel --help"
Enter
Sleep 6s

Enter 2
Type "Let's select the custom kernel 6.1.59-rt16-x64v3-xanmod1"
Sleep 1s
Type "" Ctrl+C
Enter 2

Type "sudo custom-kernel"
Enter
Sleep 4s
Type "3"
Sleep 500ms
Enter
Sleep 4s

Enter 2
Type "Let's update the custom kernel 6.1.59-rt16-x64v3-xanmod1 to it's newest version"
Sleep 1s
Type "" Ctrl+C
Enter 2

Type "sudo custom-kernel --update"
Enter
Sleep 4s

Enter 2
Type "Let's select another custom kernel 6.9.6-1-liquorix-amd64"
Sleep 1s
Type "" Ctrl+C
Enter 2

Type "sudo custom-kernel"
Enter
Sleep 4s
Type "6"
Sleep 500ms
Enter
Sleep 4s

Enter 2
Type "Let's try to update the custom kernel 6.9.6-1-liquorix-amd64 to a newer version"
Sleep 1s
Type "" Ctrl+C
Enter 2

Type "sudo custom-kernel --update"
Enter
Sleep 4s

