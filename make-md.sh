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
# We require bash scripts that are intended to be converted to start as follows:
#
#     #!/bin/bash
#
#     # Human readable title on this line
#     # =================================
#     # space-separated tags go here
#     #
#     # First subheading marks end of excerpt
#     # -------------------------------------
#
# And now, teh codez.
# -------------------

# Get the date.

today=`date +%Y-%m-%d`

# Store to the Jekyll posts folder.

outfile="_posts/$today-$1.md"

# Strip the hash-bang.

tail -n +3 $1 > $outfile

# Indent everything, so the code gets indented.

sed -i 's/\(^.*$\)/    \1/' $outfile

# Dedent and strip leading # from comments.

sed -i 's/^    #$//' $outfile
sed -i 's/^    # \(.*$\)/\1/' $outfile

# Add Jekyll front-matter.

sed -i "1s;^;---\nlayout: post\ntitle: ;" $outfile

# Treat the first line after the Heading as tags, and close out the front-matter.

sed -i '/^===/N;s/=\+\n\(.*\)/tags: \1\n---/' $outfile
