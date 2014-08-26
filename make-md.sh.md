Convert Literate BASH to Markdown
=================================

What the title says. This script powers this repository.
    
Strip the hash-bang.
    
    tail -n +3 $1 > $1.md
    
Indent everything, so the code gets indented.
    
    sed -i 's/\(^.*$\)/    \1/' $1.md
    
Dedent and strip leading # from comments.
    
    sed -i 's/^    #$//' $1.md
    sed -i 's/^    # \(.*$\)/\1/' $1.md
