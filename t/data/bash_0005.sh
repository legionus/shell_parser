# ok: bash, ksh, mksh
# fail: dash
[[ ( ! -e . ) && $((nowdate - (60 * 60 * 24))) -lt ${treedate} ]] || echo ok
