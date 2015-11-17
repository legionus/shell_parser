if true; then
    #1
    for i #2
        in 1 #3
    do #4
        echo A #5
    done | #6
        sed -e 's/A/X/' && #7
        echo Y #8
    #9
fi
