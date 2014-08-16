bridge_pre_start()
{
	(
	if [ -n "${ports}" ]; then
		einfo "Adding ports to ${IFACE}"
		eindent

		local BR_IFACE="${IFACE}"
		for x in ${ports}; do
			ebegin "${x}"
			local IFACE="${x}"
			local IFVAR=$(shell_var "${IFACE}")
		done
		eoutdent
	fi
	) || return 1

	# Bring up the bridge
	_set_flag promisc
	_up
}
