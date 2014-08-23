cat <<$(echo "foo")
line5 $(pwd)
$(echo foo)
cat <<$(echo foo)
line6 $(pwd)
$(echo foo)
cat <<$(echo foo)""
line7 $(pwd)
$(echo foo)
