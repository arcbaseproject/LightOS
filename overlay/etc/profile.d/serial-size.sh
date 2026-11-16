# A serial console can't report its window size; ask the terminal so programs use the full window.
case $(tty) in /dev/ttyS*) resize >/dev/null ;; esac
