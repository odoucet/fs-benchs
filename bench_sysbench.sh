#!/bin/bash

TESTS[0]="btrfs-default"
TESTS[1]="btrfs-lzo"
TESTS[2]="ext4"
TESTS[3]="xfs-default"

MOUNT_FS[0]="btrfs"
MOUNT_FS[1]="btrfs"
MOUNT_FS[2]="ext4"
MOUNT_FS[3]="xfs"

MKFS[0]="mkfs.btrfs"
MKFS[1]="mkfs.btrfs"
MKFS[2]="mkfs.ext4 -F"
MKFS[3]="mkfs.xfs -f"

MOUNT_OPTIONS[0]="noatime,nodiratime"
MOUNT_OPTIONS[1]="noatime,nodiratime,compress=lzo"
MOUNT_OPTIONS[2]="noatime,nodiratime"
MOUNT_OPTIONS[3]="noatime,nodiratime"

DEVICES[0]="/dev/sas3t/lv_sas3t"


# device size in MB
DEVICESIZE[0]="2831150"


########################################################################################
MOUNTPOINT="/mnt/test"
SYSBENCH="/usr/src/sysbench/sysbench/sysbench"

########################################################################################
echo $(date +"[%H:%M:%S] ")"Preparing benchmark ..."
uname -a
lvs --version
mkfs.btrfs -V
mkfs.ext4 -V

ulimit -n 1048576

if [ ! -d "$MOUNTPOINT" ]; then
    mkdir -m 0 $MOUNTPOINT;
else
    umount -f $MOUNTPOINT 2>/dev/null;
    rmdir $MOUNTPOINT;
    mkdir -m 0 $MOUNTPOINT;
fi

id=0;
for DEVICE in "${DEVICES[@]}"; do
  it=0;
  for TEST in "${TESTS[@]}"; do
      echo "it="$it" ; id="$id

      # Test SysBench
      if [ -f "sysbench_"$id"-"$TEST".csv" ]; then
          echo $(date +"[%H:%M:%S] ")"SKIP BENCHMARK Sysbench "$TEST" on "$DEVICE;
      else
          echo $(date +"[%H:%M:%S] ")"BENCHMARK Sysbench "$TEST" on "$DEVICE;
          echo $(date +"[%H:%M:%S] ")"MKFS device "$DEVICE;
          ${MKFS[$it]} $DEVICE;

          echo $(date +"[%H:%M:%S] ")"Mounting device"
          mount -t ${MOUNT_FS[it]} -o ${MOUNT_OPTIONS[it]} $DEVICE $MOUNTPOINT;
          if  [ "$?" -ne "0" ]; then
              continue
          fi

          echo $(date +"[%H:%M:%S] ")"Launching vmstat in background ...";
          vmstat -n 1 >> "vmstatsysbench_"$id"_"$TEST".csv" &

          echo $(date +"[%H:%M:%S] ")"Prepare   Sysbench ...";
          cd $MOUNTPOINT && $SYSBENCH --test=fileio --file-num=64 --file-total-size=10G prepare >/dev/null

          echo $(date +"[%H:%M:%S] ")"Launching Sysbench ...";

          # legend
          cd /mnt ;
          echo "testmode thread blocksize loop read write sync latency" > "sysbench_"$id"-"$TEST".csv"
          for testmode in seqrd seqwr rndrd rndwr  ; do #rndrw
              for thread in 1 4 12 16 24 32 128 256 1024; do #
                for bs in 512 4096 16384 1048576; do #131072 262144 
                  echo $(date +"[%H:%M:%S] ")"  test="$testmode" thread="$thread" ";
                  cd $MOUNTPOINT && $SYSBENCH --test=fileio --file-test-mode=$testmode \
                  --file-num=64 --file-total-size=10G --max-time=60  \
                  --max-requests=0 --num-threads=$thread --rand-init=on --file-extra-flags=sync \
                  --file-fsync-freq=0 --file-io-mode=sync --file-block-size=$bs  \
                  --report-interval=1 run |fgrep " writes:" |
                  awk -v tm=$testmode -v blocksize=$bs -v thr=$thread 'BEGIN{ i=0 } { gsub("ms", "", $13); \
                  gsub("/s", "", $10) ;  print tm" "thr" "blocksize" "i" "$4" "$7" "$10" "$13 ; i++ ; \
                  }' >> "../sysbench_"$id"-"$TEST".csv"
                  echo 3 > /proc/sys/vm/drop_caches
                done;
              done;
          done;

          cd /mnt ;

          echo $(date +"[%H:%M:%S] ")"Finished test Sysbench";
          killall vmstat
          sleep 5
          killall -9 vmstat
          umount -f $MOUNTPOINT;
      fi


      it=`expr $it + 1`;
  done
  id=`expr $id + 1`;
done # end for DEVICES
