if [ $HOME = /root ]
then echo OK
fi

if false
    true; then echo OK; fi
if
	echo foo
	echo bar
then
echo baz
fi
