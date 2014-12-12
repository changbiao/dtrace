#!/usr/bin/bash

if [ -z "$1" ]
  then
    export HOSTNAME=`hostname`
  else
    export HOSTNAME=$1
fi

if [ -z "$2"] ]
  then
    export INTERVAL=10
  else
    export INTERVAL=$2
fi

/usr/sbin/dtrace -Cn '

#pragma D option quiet

svc_xprt_qput:entry
{
        @pending_reqs  = max(args[0]->p_reqs);
        @act_threads   = max(args[0]->p_threads - args[0]->p_asleep);
        @pool_pct_util = max(100 * (args[0]->p_threads - args[0]->p_asleep) / args[0]->p_maxthreads);
}

tick-'$INTERVAL'sec
{
	@wts_sec = max(walltimestamp / 1000000000);

        printa("PUTVAL '$HOSTNAME'.nfs/req/gauge-maxpending %@d:%@d\n", @wts_sec, @pending_reqs);
        printa("PUTVAL '$HOSTNAME'.nfs/req/gauge-maxactive %@d:%@d\n", @wts_sec, @act_threads);
        printa("PUTVAL '$HOSTNAME'.nfs/req/gauge-pct_util %@d:%@d\n", @wts_sec,@pool_pct_util);

        trunc(@pending_reqs); 
        trunc(@act_threads); 
        trunc(@pool_pct_util);
}
'
