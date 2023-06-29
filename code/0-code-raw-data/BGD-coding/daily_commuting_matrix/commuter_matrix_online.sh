#!/bin/bash
MP_LIB="/usr/local/hadoop/share/hadoop/common/hadoop-common-2.7.2.jar:/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-core-2.7.2.jar"

function commuter_flow () {
    mkdir workspace
    mkdir workspace/commuter_matrix_1
    mkdir workspace/commuter_matrix_2
    mkdir ../output
    if javac -classpath "$MP_LIB" -d workspace/commuter_matrix_1/ CommuterFlow1.java; then
        if javac -classpath "$MP_LIB" -d workspace/commuter_matrix_2/ CommuterFlow3.java; then
            hdfs dfs -rm -r /hadoop
            hdfs dfs -mkdir /hadoop
            hdfs dfs -put "$INPUT_PATH" /hadoop/input_commuter

            jar -cvf workspace/commuter_matrix_1.jar -C workspace/commuter_matrix_1/ .
            hadoop jar workspace/commuter_matrix_1.jar CommuterFlow1 /hadoop/input_commuter /hadoop/working_commuter

            jar -cvf workspace/commuter_matrix_2.jar -C workspace/commuter_matrix_2/ .
            hadoop jar workspace/commuter_matrix_2.jar CommuterFlow3 /hadoop/working_commuter/ /hadoop/output_commuter/ "$YEAR_MONTH"

            mkdir "../output/output_$DATETIME"
            hdfs dfs -get /hadoop/output_commuter "../output/output_$DATETIME"
        fi
    fi
}

git fetch
git reset --hard origin/master
mkdir ../logs
mkdir ../logs/commuter_matrix/

INPUT_PATH="/home/ubuntu/GP-CDR/gpcdr_201308.tsv"
YEAR_MONTH="201308"
DATETIME="$(date +%Y-%m-%d-%H-%M-%S)" 
commuter_flow 2>&1 | tee ../logs/commuter_matrix/$DATETIME.log

INPUT_PATH="/home/ubuntu/GP-CDR/gpcdr_201309.tsv"
YEAR_MONTH="201309"
DATETIME="$(date +%Y-%m-%d-%H-%M-%S)" 
commuter_flow 2>&1 | tee ../logs/commuter_matrix/$DATETIME.log

INPUT_PATH="/home/ubuntu/GP-CDR/gpcdr_201311.tsv"
YEAR_MONTH="201311"
DATETIME="$(date +%Y-%m-%d-%H-%M-%S)" 
commuter_flow 2>&1 | tee ../logs/commuter_matrix/$DATETIME.log

INPUT_PATH="/home/ubuntu/GP-CDR/gpcdr_201312.tsv"
YEAR_MONTH="201312"
DATETIME="$(date +%Y-%m-%d-%H-%M-%S)" 
commuter_flow 2>&1 | tee ../logs/commuter_matrix/$DATETIME.log