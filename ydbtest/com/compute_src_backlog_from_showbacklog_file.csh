#!/usr/local/bin/tcsh -f
#################################################################
#								#
# Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

# This script computes the source side backlog from the MUPIP REPLIC -SOURCE -SHOWBACKLOG output.
# The output is present in a file that is passed in as $1.
# It is possible for multiple showbacklog outputs to be present in the same file (for example, if the caller is RF_sync.csh).
# In that case, the LAST showbacklog output is taken into account for the calculations (hence the "tail -1" below).

set logfile = $1

# Note that this script can be invoked for pre-V7.0-001 builds too in which case, the showbacklog output
# is different. So use different logic to parse the output based on whether the output is of the older form or newer form.
# In the older format, the backlog would be already computed in the output. It would be a line of the following form.
#	0 : backlog number of transactions written to journal pool and yet to be sent by the source server
# So check for the above first.
set backlog = `$grep "backlog number of transactions" $logfile | tail -1 | $tst_awk '{print $1}'`
if ("$backlog" != "") then
	# The output is pre-V70001 format
	echo $backlog
	exit
endif

# The output is post-V70001 format.
# We need to compute the backlog from the posted vs sent sequence numbers.
set posted = `$tst_awk '/Last transaction sequence number posted/ {print $NF}' $logfile | tail -1`
if ("" == $posted) then
	echo "COMPUTE_SRC_BACKLOG-E-FAIL1 : No [posted] sequence number found in $logfile"
	exit -1
endif

set sent = `$tst_awk '/Last transaction sequence number sent/ {print $NF}' $logfile| tail -1`
if ("" == $posted) then
	echo "COMPUTE_SRC_BACKLOG-E-FAIL2 : No [sent] sequence number found in $logfile"
	exit -1
endif

set backlog = `expr $posted - $sent`
echo $backlog

