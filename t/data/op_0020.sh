cat <<'E'N'D'
line1
END
cat <<"$foo"
line2
$foo
cat <<"E'O'F"
line3
E'O'F
