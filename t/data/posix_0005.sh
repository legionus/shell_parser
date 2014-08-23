cat <<HELLO
You are in $(pwd)!
cat <<EOF
HELLO
cat <<'HELLO' | tr '[A-Z]' '[a-z]'
You are in $(pwd)!
cat <<EOF
HELLO
