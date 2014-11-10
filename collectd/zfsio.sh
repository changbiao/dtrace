#!/usr/bin/bash

export HOSTNAME=`hostname`

/usr/sbin/dtrace -Cn '

#pragma D option quiet

/* Description: This script will show read/write IOPs and throughput for ZFS
 * filesystems and zvols on a per-dataset basis. It can be used to estimate
 * which dataset is causing the most I/O load on the current system. It should 
 * only be used for comparative analysis. */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2012, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.4b */

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && args[3]/ /* Reads */
{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        this->path = strjoin(strjoin(this->parent,"/"),this->ds); /* Dirty hack - parent/this format doesnt guarantee full path */
        @ior[this->path] = count();
        @tpr[this->path] = sum(args[2]);
        @bsr[this->path] = avg(args[2]);
	@wts_sec[this->path] = max(walltimestamp / 1000000000);
        @distr[strjoin(this->path, " Reads")] = quantize(args[2]);
}

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && !args[3]/ /* Writes */
{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        this->path = strjoin(strjoin(this->parent,"/"),this->ds);
        @iow[this->path] = count();
        @tpw[this->path] = sum(args[2]);
        @bsw[this->path] = avg(args[2]);
	@wts_sec[this->path] = max(walltimestamp / 1000000000);
        @distw[strjoin(this->path, " Writes")] = quantize(args[2]);
}

tick-10sec,END
{
        printa("PUTVAL '$HOSTNAME'.zfs/%s/reads %@d:%@d\n", @wts_sec, @ior);
        printa("PUTVAL '$HOSTNAME'.zfs/%s/writes %@d:%@d\n", @wts_sec, @iow);
        printa("PUTVAL '$HOSTNAME'.zfs/%s/r_bytes %@d:%@d\n", @wts_sec, @tpr);
        printa("PUTVAL '$HOSTNAME'.zfs/%s/w_bytes %@d:%@d\n", @wts_sec, @tpw);
        printa("PUTVAL '$HOSTNAME'.zfs/%s/r_bs %@d:%@d\n", @wts_sec, @bsr);
        printa("PUTVAL '$HOSTNAME'.zfs/%s/w_bs %@d:%@d\n", @wts_sec, @bsw);



        trunc(@ior); trunc(@tpr); trunc(@iow); trunc(@tpw); trunc(@bsr); trunc(@bsw); trunc(@wts_sec);
     /* clear(@ior); clear(@tpr); clear(@iow); clear(@tpw); clear(@bsr); clear(@bsw);*/
     /* TODO: Make script more interactive. Above, uncomment clear() and comment trunc() line in order to change
        truncate behavior, or comment out both lines to get cumulative stats. */
}
'
