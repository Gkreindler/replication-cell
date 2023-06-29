#!/bin/bash

function get_home_office () {
    WORKING_DIR="${OUTPUT_BASE_DIR}/working_${DATETIME}"
    OUTPUT_DIR="${OUTPUT_BASE_DIR}/output_${DATETIME}"
    OUTPUT_SUBDIR_1="${OUTPUT_DIR}/user_home_office_list"
    OUTPUT_SUBDIR_2="${OUTPUT_DIR}/tower_user_info"
    OUTPUT_SUBDIR_ENT="${OUTPUT_DIR}/entropy"
    mkdir -p $OUTPUT_DIR


    # reset directories
    hdfs dfs -rm -r /hadoop
    #hdfs dfs -rm -r /hadoop/working2 /hadoop/output2
    hdfs dfs -mkdir /hadoop /hadoop/input

    # compile
    if !(javac -classpath $MP_LIB -d $WORKSPACE_DIR/code/ $SOURCE_DIR/GetHomeOffice1.java); then
        exit 1
    fi

    if !(javac -classpath $MP_LIB -d $WORKSPACE_DIR/code/ $SOURCE_DIR/GetHomeOffice2.java); then
        exit 1
    fi

    if !(javac -classpath $MP_LIB -d $WORKSPACE_DIR/code/ $SOURCE_DIR/GetEntropy1.java); then
        exit 1
    fi

    if !(javac -classpath $MP_LIB -J-Xmx1024m -d $WORKSPACE_DIR/code/ $SOURCE_DIR/GetHomeOffice3.java); then
        exit 1
    fi

    if !(javac -classpath $MP_LIB -J-Xmx1024m -d $WORKSPACE_DIR/code/ $SOURCE_DIR/GetHomeOffice4.java); then
        exit 1
    fi

    jar -cvf $WORKSPACE_DIR/get_home_office.jar -C $WORKSPACE_DIR/code/ .

    # Step 1
    copy input files to /hadoop/input
    for path in "${INPUT_PATHS[@]}"; do
        hdfs dfs -put $path /hadoop/input
    done
    ## execute
    hadoop jar $WORKSPACE_DIR/get_home_office.jar \
        GetHomeOffice1 /hadoop/input /hadoop/working \
        $BASE_DIR/tools/ant10_tower_table.csv \
        $BASE_DIR/tools/hartal_list.csv \
        $BASE_DIR/tools/weekend_holiday_list.csv

    # Entropy 1
    hadoop jar $WORKSPACE_DIR/get_home_office.jar GetEntropy1 /hadoop/working /hadoop/output_ent $BASE_DIR/tools/ant10_tower_table.csv
    hdfs dfs -get /hadoop/output_ent $OUTPUT_SUBDIR_ENT
    python $BASE_DIR/tools/aggregate_mapred_outputs.py \
        --input_dir=$OUTPUT_SUBDIR_ENT \
        --output_path=$OUTPUT_DIR/entropy.csv \
        --header="userid,num_unique_towers,num_total_count,centroid_lon,centroid_lat,gyration,entropy" 

    # Step 2
    hadoop jar $WORKSPACE_DIR/get_home_office.jar GetHomeOffice2 /hadoop/working /hadoop/output
    hdfs dfs -get /hadoop/output $OUTPUT_SUBDIR_1
    python $BASE_DIR/tools/aggregate_mapred_outputs.py \
        --input_dir=$OUTPUT_SUBDIR_1 \
        --output_path=$OUTPUT_DIR/user_home_office_list.csv \
        --header="userid,home_work_dummy,Tmax,Tmaxfreq,totfreq" 

    # Merge entropy.csv and user_home_office_list.csv
    python $SOURCE_DIR/merge_entropy_homeoffice.py \
        --entropy_path=$OUTPUT_DIR/entropy.csv \
        --user_home_office_list_path=$OUTPUT_DIR/user_home_office_list.csv \
        --output_path=$OUTPUT_DIR/tower_entropy.csv

    exit 0
    #cp /home/ubuntu/bangla/output/output_2019-10-17-15-23-48/user_home_office_list.csv $OUTPUT_DIR

    # Step 3
    hadoop jar $WORKSPACE_DIR/get_home_office.jar \
        GetHomeOffice3 /hadoop/input /hadoop/working2 \
        $BASE_DIR/tools/ant10_tower_table.csv

    # Step 4
    hadoop jar $WORKSPACE_DIR/get_home_office.jar \
        GetHomeOffice4 /hadoop/working2 /hadoop/output2 \
        $OUTPUT_DIR/user_home_office_list.csv \
        $BASE_DIR/tools/google_map_traveltime_between_towers.csv
    hdfs dfs -get /hadoop/output2 $OUTPUT_SUBDIR_2
    python $BASE_DIR/tools/aggregate_mapred_outputs.py \
        --input_dir=$OUTPUT_SUBDIR_2 \
        --output_path=$OUTPUT_DIR/tower_user_info.csv \
        --header="tower,date,hour,totfreq,num_unique_users,average_home_min,average_office_min,home_count,office_count,total_duration,duration_count" 
}

if [ $USER = "myuuuuun" ]; then
    echo "Run command in local."
    HADOOP_VER="3.2.1"
    MP_LIB="$HADOOP_ROOT/libexec/share/hadoop/common/hadoop-common-$HADOOP_VER.jar"
    MP_LIB="$MP_LIB:$HADOOP_ROOT/libexec/share/hadoop/mapreduce/hadoop-mapreduce-client-core-$HADOOP_VER.jar"
    BASE_DIR="$HOME/bangla"
    INPUT_PATHS=(
        "$BASE_DIR/sample_input/input_commuting/sample_data.tsv" 
        "$BASE_DIR/sample_input/input_commuting/sample_data_2.tsv"
    )

elif [ $USER = "ubuntu" ]; then
    echo "Run command in EC2."
    git pull origin master
    HADOOP_VER="2.8.5"
    MP_LIB="/usr/local/hadoop/share/hadoop/common/hadoop-common-$HADOOP_VER.jar"
    MP_LIB="$MP_LIB:/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-core-$HADOOP_VER.jar"
    BASE_DIR="/home/ubuntu/bangla"

    INPUT_PATH_08="/home/ubuntu/GP-CDR/gpcdr_201308.tsv"
    INPUT_PATH_09="/home/ubuntu/GP-CDR/gpcdr_201309.tsv"
    INPUT_PATH_11="/home/ubuntu/GP-CDR/gpcdr_201311.tsv"
    INPUT_PATH_12="/home/ubuntu/GP-CDR/gpcdr_201312.tsv"
    INPUT_PATHS="$INPUT_PATH_08 $INPUT_PATH_09 $INPUT_PATH_11 $INPUT_PATH_12"

else
    echo "Invalid username: ${USER}"
    exit 1
fi

OUTPUT_BASE_DIR="$BASE_DIR/output"
SOURCE_DIR="$BASE_DIR/commuting_panel/code/get_home_office/"
WORKSPACE_DIR="$BASE_DIR/get_home_office/workspace"
LOG_BASE_DIR="$BASE_DIR/logs"
LOG_DIR="$LOG_BASE_DIR/get_home_office"
mkdir -p $OUTPUT_BASE_DIR $WORKSPACE_DIR $WORKSPACE_DIR/code $LOG_DIR
DATETIME="$(date +%Y-%m-%d-%H-%M-%S)"

get_home_office 2>&1 | tee "${LOG_DIR}/${DATETIME}.log"
