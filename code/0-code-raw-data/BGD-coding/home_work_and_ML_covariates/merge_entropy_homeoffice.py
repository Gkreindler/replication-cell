import pandas as pd
import argparse
import pathlib
pd.set_option("display.max_columns", 1000)
pd.set_option("display.width", 1000)

    
def aggregate_tower_info(entropy_path, user_home_office_list_path, output_path):
    entropy_df = pd.read_csv(
        entropy_path, 
        usecols=["userid", "num_unique_towers", "num_total_count", "gyration", "entropy"]
    )
    user_df = pd.read_csv(
        user_home_office_list_path, 
        usecols=["userid", "home_work_dummy", "Tmax"]
    )
    df = pd.merge(entropy_df, user_df, on=["userid"])
    mean_df = df.groupby(["Tmax", "home_work_dummy"]).mean().reset_index().sort_values(by=["Tmax", "home_work_dummy"])
    mean_df.to_csv(output_path, index=False)


if __name__ == "__main__":
    """
    Settings
    """ 
    # parse command line args (test flag)
    parser = argparse.ArgumentParser()
    parser.add_argument("--entropy_path")
    parser.add_argument("--user_home_office_list_path")
    parser.add_argument("--output_path")
    args, leftovers = parser.parse_known_args()
    aggregate_tower_info(args.entropy_path, args.user_home_office_list_path, args.output_path)

