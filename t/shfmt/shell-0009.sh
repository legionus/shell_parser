case "$foo" in
(123) ;;
ABC=*) echo "test";;
*)
    echo "foo bar";
    ;;
esac

case "foo=1" in (bar) if true; then echo nop; fi; case 1 in *) ;; if) ;; esac;; foo=*) echo 'ok';; esac

case foo in *) echo 1; esac
