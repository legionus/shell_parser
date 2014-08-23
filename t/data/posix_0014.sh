clip_pre_stop()
{
	eindent
	{
		read left && \
		while read itf t encp idle ipaddr left; do
			if [ "${itf}" = "${IFACE}" ]; then
				ebegin "Removing PVC to ${ipaddr}"
				atmarp -d "${ipaddr}"
				eend $?
			fi
		done
	} < /proc/net/atm/arp
	eoutdent
}
