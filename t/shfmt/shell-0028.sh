if x=$(cat /etc/passwd |grep -qs root); then
	echo OK;
fi
