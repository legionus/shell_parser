while read a; do
   echo a:$a
done <<EOF |
aaa
bbb
ccc
EOF
while read b; do
   echo b:$b
done

while read a; do
   echo a:$a
done <<EOF |while read b; do
aaa
bbb
ccc
EOF
   echo b:$b
done

while read a; do echo a:$a; done <<EOF | while read b; do echo b:$b; done
aaa
bbb
ccc
EOF
