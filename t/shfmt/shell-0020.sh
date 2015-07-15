if cat <<EOF |grep -iqs foo
FOO
EOF
then
	echo OK
fi
