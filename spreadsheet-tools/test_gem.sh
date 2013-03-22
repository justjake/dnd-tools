#!/usr/bin/env zsh
# test this gem without loading the installed version of libraries

CMD=pathfinder

set -e
source $ZSH_FILES/functions.zsh

exec ruby -I $(this-script-dir)/lib $(this-script-dir)/bin/$CMD
