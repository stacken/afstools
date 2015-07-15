#!/bin/bash
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Stefan Berggren <nsg@stacken.kth.se>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

logger() {
	echo -e "# $1"
}


server=$1
toserver=$2
logfile=$(mktemp)

logger "Tail $logfile for more information"

for type in RO RW; do
	for part in $(vos listpart -noauth -server $server | grep '/' | tr -d '/'); do

		# Get part with most free space on target server
		target="$(vos partinfo -noauth -server $toserver | awk '{print $6" "$5}' | tr -d '/:' | tr ' ' ':' | sort -r | head -1)"
		target_freespace=${target%%:*}
		target_part=${target##*:}

		# Get used space on source
		source="$(vos partinfo -noauth -server $server | awk "/$part/{print \$6\" \"\$12}")"
		source_freespace=${source%% *}
		source_totalspace=${source##* }
		source_spaceused=$(($source_totalspace - $source_freespace))

		if [ $source_spaceused -gt $target_freespace ]; then
			logger "The target server $toserver is full, abort!"
			logger "target free: $target_freespace K"
			logger "source used: $source_spaceused K"
			exit 1
		fi

		logger "Moving $type volumes to target"
		logger "$server:$part -> $toserver:$target_part"

		for vol in $(vos listvol -noauth $server $part | awk "{if (\$3 == \"$type\"){print \$1}}"); do
			logger "Source: $server \t$part\t$vol"
			logger "Target: $toserver\t$target_part"
			vosmove2 $vol $server $part $toserver $target_part -local >> $logfile 2>&1 || (
					logger "Failed! check the log at $logfile";
					exit 1
				)
			echo -n "Volumes "
			echo -n "$(vos listvol -noauth -server $server | grep $part | awk '{print $NF}') -> "
			echo -n "$(vos listvol -noauth -server $toserver | grep $target_part | awk '{print $NF}') "
			echo "($(($(vos partinfo -noauth -server beef | awk '/vicepa/{print $12" - "$6}'))) blocks left)"
			logger "Done, this is a good time to abort the script"
			sleep 5
			echo
		done
	done
done


