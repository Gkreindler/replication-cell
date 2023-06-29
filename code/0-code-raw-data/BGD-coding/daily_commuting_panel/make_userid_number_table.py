# make userid - number table

import os
import sys
import numpy as np
import pandas as pd
import csv
import datetime


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise ValueError("need 2 arguments(base_dir, output_path)")

    base_dir = sys.argv[1]
    output_path = sys.argv[2]

    # collect all mapreduce outputs
    base_file_path_list = []
    for (dirpath, dirnames, filenames) in os.walk(base_dir):
        for f in filenames:
            if ".txt" in f:
                base_file_path_list.append(os.path.join(base_dir, dirpath, f))

    print("Start aggregating outputs")
    for i, path in enumerate(base_file_path_list):
        if i == 0:
            df = pd.read_csv(path, delimiter=",", header=None, usecols=[0], names=["uid"])
            print("Add {}".format(path))
        else:
            try:
                df_ = pd.read_csv(path, delimiter=",", header=None, usecols=[0], names=["uid"])
                df = df.append(df_)
                df.drop_duplicates(inplace=True)
                print("Add {}".format(path))
            except pd.io.common.EmptyDataError:
                print("No data in {}".format(path))

    df.drop_duplicates(inplace=True)
    df.sort_values(inplace=True, by="uid")
    df.reset_index(inplace=True, drop=True)
    df.index += 1 
    df.to_csv(output_path, sep=",", header=None)
    print("Finish aggregating outputs")
    