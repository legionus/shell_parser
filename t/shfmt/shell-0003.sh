xxx1() { ls -l -a; }

xxx2() { echo OK; } >&2

xxx3() { echo ${foo:-'}'}; }

xxx4() { echo ${foo:-"}"}; }
