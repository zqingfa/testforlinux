#!/bin/bash
# 所有文件复制到/opt/test目录下
mkdir -p /opt/logs/fio
mkdir -p /opt/logs/sysbench
mkdir -p /opt/logs/ltp
mkdir -p /opt/logs/ltpstress
chmod +x -R /opt/test



# 测试bench的IO
cd /opt/test
./bench.sh  -io > /opt/logs/bench-io.log


#fio测试

for i in {1..9}
do
fio  -directory=/datapool/ -direct=1 -runtime=300 -iodepth=128 -rw=read -ioengine=libaio -bs=512k -size=100G -numjobs=1 -group_reporting -name=512k-read > /opt/logs/fio/fio$i.log

#2.     Write Bandwidth test  写带宽测试
fio  -directory=/datapool/ -direct=1 -runtime=300 -iodepth=128 -rw=write -ioengine=libaio -bs=512k -size=100G -numjobs=1 -group_reporting -name=512k-write >> /opt/logs/fio/fio$i.log
#rm -rf /datapool/

#3.     Read IOPS test    随机读测试
fio  -directory=/datapool/ -direct=1 -runtime=300 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=100G -numjobs=1 -group_reporting -name=4k-random_read >> /opt/logs/fio/fio$i.log
#rm -rf /datapool/

#4.     Write IOPS test 随机写测试
fio  -directory=/datapool/ -direct=1 -runtime=300 -iodepth=128 -rw=randwrite  -ioengine=libaio -bs=4k -size=100G -numjobs=1 -group_reporting -name=4k-random_write >> /opt/logs/fio/fio$i.log
#rm -rf /datapool/

done

#memtester测试
cd /opt/test/memtester
tar zxvf memtester-4.3.0.tar.gz 
cd memtester-4.3.0 
make && make install
memtester 14G 3 > /opt/logs/memtester.log
 
# sysbench
cd /opt/test/sysbench/
tar xf 1.0.17.tar.gz
cd sysbench-1.0.17
yum -y install make automake libtool pkgconfig libaio-devel
yum -y install mariadb-devel openssl-devel
yum -y install postgresql-devel

./autogen.sh
./configure
make -j
make install



sysbench --test=cpu --cpu-max-prime=2000 run > /opt/logs/sysbench/cpu.log
sysbench  threads --num-threads=500 --thread-yields=100 --thread-locks=4 run  > /opt/logs/sysbench/threads.log

echo "======================  read  ==============================" > /opt/logs/sysbench/memory.log
sysbench memory  --memory-oper=read run > /opt/logs/sysbench/memory.log
echo "======================  write  =============================" >> /opt/logs/sysbench/memory.log
sysbench memory  --memory-oper=write run >> /opt/logs/sysbench/memory.log
echo "=======================  rand read  ============================" >> /opt/logs/sysbench/memory.log
sysbench memory  --memory-oper=read --memory-access-mode=rnd run >> /opt/logs/sysbench/memory.log
echo "=======================  rand write  =======================" >> /opt/logs/sysbench/memory.log
sysbench memory  --memory-oper=write --memory-access-mode=rnd run >> /opt/logs/sysbench/memory.log


sysbench mutex  --mutex-num=1000 --mutex-locks=100000 --mutex-loops=10000 run > /opt/logs/sysbench/mutex.logs

# unixbench测试
cd /opt/test/unixbench
./unixbench.sh > /opt/logs/unixbench.log

# LTP测试
cd /opt/test/ltp/
xz -d ltp-full-20190517.tar.xz
tar xf ltp-full-20190517.tar
cd ltp-full-20190517

make autotools
./configure
make
make install

cd /opt/ltp
#初始测试：
./runltp -p -l /opt/logs/resultlog  -o /opt/logs/ltp/ltpscreen -C /opt/logs/ltp/result-failed.log -d /opt/ltp -g /opt/logs/ltp/reslut-html.html -t 12h 
#压力测试：
./ltpstress.sh -d /opt/logs/ltpstress/ltpstress.sardata -l /opt/logs/ltpstress/ltpstress.log -I /opt/logs/ltpstress/ltpstress.iodata  -m 256000 -S

cd /opt/logs/ltpstress
echo "平均CPU使用率" > reslut.log
sar -u -f ltpstress.saradata >> reslut.log
echo "平均CPU使用率">> reslut.log
sar -r -f ltpstress.saradata >> reslut.log