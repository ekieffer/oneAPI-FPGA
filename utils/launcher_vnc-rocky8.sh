#!/bin/bash -l
#SBATCH --nodes=1                          # number of nodes
#SBATCH --ntasks=2                         # number of tasks
#SBATCH --cpus-per-task=1                  # number of cores per task
#SBATCH --time=40:00:00                    # time (HH:MM:SS)
#SBATCH --account=p200117                  # project account
#SBATCH --partition=cpu                   # partition
#SBATCH --qos=default                         # QOS
##SBATCH --mail-user=emmanuel.kieffer@uni.lu
##SBATCH --mail-type=BEGIN,FAIL,END

module load Singularity-CE/3.10.2-GCCcore-11.3.0

IP_ADDRESS=$(hostname -I | awk '{print $1}')
WEB_PORT="8020"
VNC_PORT="5910"
FORWARD_PORT="9910"
echo "On your laptop: ssh -p 8822 -NL ${FORWARD_PORT}:${IP_ADDRESS}:${WEB_PORT} ${USER}@login.lxp.lu "
echo "Open following link http://localhost:${FORWARD_PORT}/vnc.html"


srun -N1 -n1 -c1 singularity exec vnc-rocky8.app /opt/websockify/run --web /opt/noVNC/ ${WEB_PORT} ${IP_ADDRESS}:${VNC_PORT} &
srun -N1 -n1 -c1 singularity exec -B /apps:/apps -B /project:/project -B /project:/project -B /mnt:/mnt  vnc-rocky8.app /bin/bash start_script.sh 2>/dev/null



