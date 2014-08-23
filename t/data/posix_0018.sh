n=`basename $s`
case "$n" in
*~ ) : ;;
#* ) : ;;
make.* ) : ;;
CVS ) : ;;
* ) if [ -f $s ]
	then
	if [ -h $build/$n ] 
		then
		$new && [ $n != Makefile ] &&  echo "$s used"
	fi
	elif [ -d $s ]
	then
	build_below ../$root $build/$n $source/$n
	fi;;
esac
