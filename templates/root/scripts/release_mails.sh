#!/bin/sh

# Get original recipients

for msgid in $(postqueue -p |sed -ne 's,^\([^!]*\)!.*,\1,p'); do
        mailfile=$(mktemp /tmp/mailfile.XXXXXXXX)
	# This is the easiest way to make it look as though it's from the original author, get the From: address and make it Reply-To:
	# If we try to spoof or even use the real From address then it makes SPF rules angry
        mailfrom=$(postcat -qbh $msgid | sed -ne 's,^From: ,,p')
        echo "Reply-To: $mailfrom" > $mailfile
        postcat -qbh $msgid >> $mailfile
	# Currently we ignore the header X-DSHS-Process value but store it here
	process_value=$(sed -ne 's,^X-DSHS-Process: \(.*\),\1,p' $mailfile)
	sed -i '' '/^X-DSHS-Process: /d' $mailfile
        # Check it's definitely meant for this purpose!
        if ! grep -q 'for <process@dshs.network>;' $mailfile; then
		rm $mailfile
		continue
	fi
	# Get first line of "To:" list
	toline=$(sed -n "/^To: /=" $mailfile)
        # Any hints on making a list of recipients would be gratefully received
	# Currently we just grab all lines, split on any delimiter and strip <> from beginning
	# and end of lines.  The case should igore irrelevant ones.
        our_recipients=
        for recipient in $(sed -n "$toline,/^[^ ]/p" $mailfile | sed '$d;1s/To: //' | tr '[,; \n]' '\n' \
		| grep -v '^$' | sed 's,^<,,;s,>$,,'); do
		# Don't duplicate to non-DSHS email addresses, that could be embarrassing
                case $recipient in
		*@droitwichspahigh.worcs.sch.uk)
                        our_recipients="$recipient${our_recipients:+,$our_recipients}"
                        ;;
		*)
                        ;;
                esac
        done

	# Do they have a name?  Or should we just use the raw email address?
        mailfrom_gecos="${mailfrom% <*}"
        if [ -n "$mailfrom_gecos" ]; then
                from="$mailfrom_gecos <mail@dshs.network>"
        else
                from="\"$mailfrom\" <mail@dshs.network>"
        fi
	# Send it.  Phew.
        if sendmail -f "$from" $our_recipients < $mailfile; then
		# If it didn't work, just blithely leave it in the queue.  Someone will notice it, I'm sure
                postsuper -d $msgid
        fi
	# Clean up
        rm $mailfile
done
