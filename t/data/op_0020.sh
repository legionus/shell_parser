cat <<'E'N'D'
line1
END
cat <<"$foo"
line2
$foo
cat <<"E'O'F"
line3
E'O'F
cat <<$(echo "foo")
line4 $(pwd)
$(echo foo)
cat <<$(echo foo)
line5 $(pwd)
$(echo foo)
cat <<$(echo foo)""
line6 $(pwd)
$(echo foo)
