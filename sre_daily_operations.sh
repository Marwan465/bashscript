#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'
DependencyLog="dependencies.log"
AnalysisLog="log_analysis.log"
SystemHealthLog="system_health.log"
MaxCpu=85
MaxMemory=85
MaxDisk=85
CriticalData="/data/critical"
BackupTo="/backup"
BackupMaxDays=7
tools=("top" "free" "df" "tar" "find")
recipient="Mohamed.ElEmam@ivolve.io"







main(){
   for i in "${tools[@]}"; do
    #command -v "$i" >/dev/null 2>&1 || { echo >> "$DependencyLog" "$(date +"%d/%m/%Y---%H:%M:%S") "$i" command wasn't found."; echo "do you want to try to install? [Y/N]."; read choice; }
    #echo "$?"
    command -v "$i" >/dev/null 2>&1 
    if [ $? -ne 0 ]; then
        { echo >> "$DependencyLog" "$(date +"%d/%m/%Y---%H:%M:%S") "$i" command wasn't found."; echo "do you want to try to install? [Y/N]."; read choice; }
        
    	installDependency "$choice" "$i" 
    	
    	
    else
    	echo -e "${GREEN}Success, The command "$i" is present${RESET}"
    	echo -e "${YELLOW}Proceeding..${RESET}"
    fi
  
   done
logAnalysis
systemHealthChecks
backupManagement

}
installDependency() {
  if [ "$1" = "Y" ]; then
  	echo -e "${BLUE}trying to install "$2"${RESET}"
  	case "$2" in
    "top"|"free")
        sudo yum install -y procps-ng >/dev/null 2>&1  || { echo "Installation Failed...Exiting"; exit 1; }
        ;;
    "df")
        sudo yum install -y coreutils >/dev/null 2>&1  || { echo "Installation Failed...Exiting"; exit 1; }
        ;;
    "find")
        sudo yum install -y findutils >/dev/null 2>&1  || { echo "Installation Failed...Exiting"; exit 1; }
        ;;
    "tar"|"htop")
        sudo yum install -y tar >/dev/null 2>&1  || { echo "Installation Failed...Exiting"; exit 1; }
        ;;
	esac
	echo -e "${GREEN}Success!${RESET}"
  else 
  	echo -e "${RED}Failed please check "$DependencyLog" ${RESET}"
    	echo -e "${RED}Aborting...${RESET}"
    	exit 1;
  fi
  unset choice
}

logAnalysis() {
 journalctl | grep error  >> "$AnalysisLog"
 sendEmail "Analysis logs" "$AnalysisLog"
}
systemHealthChecks() {
     cpu_usage=$(top -b -n1 | grep "Cpu(s)" | awk '{printf "%.0f\n", $2 + $4}')
     memory_usage=$(free | awk '/Mem/{printf "%.0f\n", $3/$2 * 100}')
     disk_usage=$(df / | awk 'NR==2 {printf "%.0f\n", $5}' | sed 's/%//')
     
     
     echo "----------------Health System logs on $(date +"%d/%m/%Y---%H:%M:%S")--------------------" >> "$SystemHealthLog"
     echo "CPU Usage: $cpu_usage%" >> "$SystemHealthLog"
     echo "MEMORY Usage: $memory_usage%" >> "$SystemHealthLog"
     echo "Root Volume Disk Usage: $disk_usage%" >> "$SystemHealthLog"
     echo "-------------------------------END-------------------------------------" >> "$SystemHealthLog"
     
     if (( cpu_usage >= MaxCpu || memory_usage >= MaxMemory || disk_usage >= MaxDisk )); then
     sendEmail  "Usage Limit Exceeded, check "$SystemHealthLog" for more info."  "$SystemHealthLog"
     
     fi
}

backupManagement() {
     mkdir -p "$BackupTo"
     tar -czf "$BackupTo/backup_$(date +"%Y%m%d").tar.gz" "$CriticalData"
     
     find "$BackupTo" -name "backup_*.tar.gz" -type f -mtime +$BackupMaxDays -exec rm -f {} \;
}

sendEmail() {
  echo -e "Dear SRE \nKindly Find The Attached logs regarding "$1" \nBest Regards,"| s-nail -v -s "$1" -a "$2"  $recipient
  #echo "Sending...."
}
main
