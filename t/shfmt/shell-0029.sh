	id="$(traverse_tree "$tree" "$dir" "$optional")" ||
		{
			[ $? -gt 1 ] && return 0 ||
				exit 1
		}
		rc=$?
