# correct result: pwd
# incorrect result: date
echo "$\
(pwd ')">/dev/null
date
echo ')" #'>/dev/null
