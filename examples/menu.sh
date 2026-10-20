#!/bin/bash
# A flat SwiftBar-style menu, unchanged between hosts.
printf 'Example\n---\n'
printf 'Local tools | color=gray size=12\n'
printf 'Open project | shell=/usr/bin/open param1=https://github.com/PVRLabs/leanbar terminal=false\n'
printf -- '---\n'
printf 'Say hello | shell=/usr/bin/say param1="Hello from LeanBar" terminal=false refresh=true\n'
