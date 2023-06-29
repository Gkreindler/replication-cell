#!/bin/bash
MP_LIB="/usr/local/hadoop/share/hadoop/common/hadoop-common-2.7.2.jar:/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-core-2.7.2.jar"

function commuting_panel () {
    WORKING_DIR="${OUTPUT_BASE_DIR}/working_${DATETIME}"
    OUTPUT_DIR="${OUTPUT_BASE_DIR}/output_${DATETIME}"

    hdfs dfs -rm -r /hadoop
    hdfs dfs -mkdir /hadoop
    hdfs dfs -mkdir /hadoop/working

    if !(javac -classpath "$MP_LIB" -d $WORKSPACE_DIR/code/ CommutingPanel1.java); then
        exit 1
    fi

    if !(javac -d "$MP_LIB" -d $WORKSPACE_DIR/code/ FormatCommutingInfo.java); then
        exit 1
    fi

    jar -cvf $WORKSPACE_DIR/commuting_panel.jar -C $WORKSPACE_DIR/code/ .

    # 1st step
    for month in "08" "09" "11" "12"; do
        hdfs dfs -rm -r /hadoop/input /hadoop/output
        INPUT_PATH_NAME="INPUT_PATH_${month}"
        hdfs dfs -put ${!INPUT_PATH_NAME} /hadoop/input
        hadoop jar $WORKSPACE_DIR/commuting_panel.jar CommutingPanel1 /hadoop/input /hadoop/output $month

        # copy outputs to /hadoop/working
        for file in `hdfs dfs -ls /hadoop/output/ | awk '{print $NF}' | grep .txt$ | tr '\n' ' '`
        do
            hdfs dfs -mv $file /hadoop/working/
        done
    done
    hdfs dfs -get /hadoop/working $WORKING_DIR
    hdfs dfs -rm -r /hadoop

    # 2nd step
    mkdir $OUTPUT_DIR
    python make_userid_number_table.py $WORKING_DIR "${OUTPUT_DIR}/userid_table.csv"

    # 3rd step
    for filename in `ls $WORKING_DIR | awk '{print $NF}' | grep .txt$ | tr '\n' ' '`
    do
        FILE_PATH="${WORKING_DIR}/${filename}"
        OUTFILE_PATH="${OUTPUT_DIR}/${filename}"
        echo "Converting userid of ${FILE_PATH}"
        java -classpath $WORKSPACE_DIR/code/ FormatCommutingInfo $FILE_PATH $OUTFILE_PATH "${OUTPUT_DIR}/userid_table.csv"
    done
}

BASE_DIR="/home/ubuntu/bangla"
OUTPUT_BASE_DIR="$BASE_DIR/output"
WORKSPACE_DIR="$BASE_DIR/commuting_panel/workspace"
LOG_BASE_DIR="$BASE_DIR/logs"
LOG_DIR="$LOG_BASE_DIR/commuting_panel"
mkdir $OUTPUT_BASE_DIR
mkdir $WORKSPACE_DIR
mkdir $WORKSPACE_DIR/code
mkdir $LOG_DIR

DATETIME="$(date +%Y-%m-%d-%H-%M-%S)"

if git fetch && git reset --hard origin/master; then 
    INPUT_PATH_08="/home/ubuntu/GP-CDR/gpcdr_201308.tsv"
    INPUT_PATH_09="/home/ubuntu/GP-CDR/gpcdr_201309.tsv"
    INPUT_PATH_11="/home/ubuntu/GP-CDR/gpcdr_201311.tsv"
    INPUT_PATH_12="/home/ubuntu/GP-CDR/gpcdr_201312.tsv"
    commuting_panel 2>&1 | tee "${LOG_DIR}/${DATETIME}.log"
fi
