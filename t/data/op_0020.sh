cat <<'E'N'D'
line1
END
cat <<"$foo"
line2
$foo
cat <<"E'N'D"
line3
E'N'D
