for sig in TERM QUIT INT; do
	cgroup_get_pids || { eend 0 "finished" ; return 0 ; }
	for i in 0 1; do
		kill -s $sig $pids
		for j in 0 1 2; do
			cgroup_get_pids || { eend 0 "finished" ; return 0 ; }
			sleep 1
		done
	done 2>/dev/null
done

