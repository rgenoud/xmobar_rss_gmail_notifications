#!/bin/sh

if [ $# -gt 3 ] || [ $# -lt 2 ] ; then
	echo "Usage: $0 rss_feed sleep_time [color]"
	echo "\trss_feed: rss feed address"
	echo "\tsleep_time: number of seconds between notifications"
	echo "\tcolor: color for xmobar ex: 5a13f0"
	exit 1
fi

feed=$1
shift
tts=$1
shift

if [ $# -eq 1 ] ; then
	color=$1
	header="<fc=#$color>"
	footer="</fc>"
else
	color=""
	header=""
	footer=""
fi

feed_file=`echo "$feed" | sed -e "s@/@_@g" -e "s@ @_@g" -e "s@:@_@g"`
feed_old_file=$feed_file.old
news=$feed_file.news
tmp_dir=/tmp/rss_notify_$USER

feed_regex="s/<title>\(.*\)<\/title>.*<summary>\(.*\)<\/summary>.*<name>\(.*\)<\/name>.*/\3 – \1 – \2/p"

# create temp dir where we are going to store the old feeds
mkdir -p $tmp_dir
if [ $? -ne 0 ] ; then
	echo "unable to create $tmp_dir; Aborting"
	exit 1
fi

# create the old feed file, so that the diff will always work
touch $tmp_dir/$feed_old_file
if [ $? -ne 0 ] ; then
	echo "unable to touch $tmp_dir/$feed_old_file; Aborting"
	exit 1
fi

# get the new feed and store it in the temp dir
curl --netrc "$feed" --silent \
	| tr -d '\n' \
	| awk -F '<entry>' '{for (i=2; i<=NF; i++) {print $i}}' \
	| sed -n "s/<title>\(.*\)<\/title>.*<name>\(.*\)<\/name>.*/\2 – \1/p" \
	| tac \
	>$tmp_dir/$feed_file
if [ $? -ne 0 ] ; then
	echo "error retrieving $feed; Aborting"
	exit 1
fi

# get only the new lines
diff -a -u $tmp_dir/$feed_old_file $tmp_dir/$feed_file \
	| grep "^+" \
	| grep -v "^+++" \
	| sed -e "s/^+//" -e "s@\$@<br/>@" \
	| html2text -utf8 -width -1 \
	| xmlstarlet unesc \
	> $tmp_dir/$news

# send notifications for each news
while read line ; do
	echo "$header$line$footer"
	sleep $tts
done < $tmp_dir/$news

mv -f $tmp_dir/$feed_file $tmp_dir/$feed_old_file

