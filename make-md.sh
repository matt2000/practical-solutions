#!/bin/bash

# Convert Literate BASH to Jekyll Markdown
# =================================
# text-processing
#
# What the title says. This script powers this repository.
#
# Literate BASH Requirements
# --------------------------
#
# We require bash scripts that are intended to be converted to be formatted
# roughly as follows, with the first 10 lines being the essential part:
#
#     #!/bin/bash
#
#     # Human readable title on this line
#     # =================================
#     # space-separated tags go here
#     #
#     # Descriptive excerpt goes here. These end up on the Jekyll home page.
#     #
#     # First subheading marks end of excerpt
#     # -------------------------------------
#
#     # We might put some code we actually want executed here...
#
#     echo "Hello World!"
#
#     # We can even put code in the comments in our code:
#     #
#     #    echo "Infinite recursion happens here. Except it doesn't. Or does it?"
#     #
#     # Scary, huh?
#
#     exit 1
#
# And now, teh codez that make that^^ into Markdown that Jekyll can make into HTML.
# -----------------------------------------

# Get the date, from the command-line, or from today.

day="$2"
if [[ -z $day ]]
then
  day=`date +%Y-%m-%d`
fi

# Store to the Jekyll posts folder.

outfile="_posts/$day-$1.md"

# Strip the hash-bang.

tail -n +3 $1 > $outfile

# Indent everything, so the code gets indented.

sed -i 's/\(^.*$\)/    \1/' $outfile

# Dedent and strip leading # from comments.

sed -i 's/^    #$//' $outfile
sed -i 's/^    # \(.*$\)/\1/' $outfile

# Add Jekyll front-matter. If we just wanted Markdown and not Jekyll posts, we
# could exit here.

sed -i "1s;^;---\nlayout: post\ntitle: ;" $outfile

# Treat the first line after the Heading as tags, and close out the front-matter.

sed -i '/^===/N;s/=\+\n\(.*\)/tags: \1\n---/' $outfile
