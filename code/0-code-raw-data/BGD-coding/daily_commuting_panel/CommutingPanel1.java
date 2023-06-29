/* CommutingPanel1.java

各日・userid毎に, 通勤情報を抽出する. 詳細はREADME

input: CBD
output: userid, date, origin_ant10, origin_lon, origin_lat, 
        destination_ant10, destination_lon, destination_lat

*/

import java.io.IOException;
import java.util.StringTokenizer;
import java.io.DataInput; 
import java.io.DataOutput; 
import java.util.ArrayList;
import java.util.List;
import java.util.Formatter;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.Writable;
import org.apache.hadoop.io.WritableComparable;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.input.TextInputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;

import org.apache.hadoop.mapreduce.TaskAttemptContext;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.FSDataOutputStream;
import org.apache.hadoop.mapreduce.RecordWriter;
import org.apache.hadoop.io.WritableUtils;

public class CommutingPanel1 {

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, Text> {
    /* <uid+date, time+ant10+lon+lat> の組にmap 
       e.g. key: 20160821,22B2F03DB6FCE5B376B897A3CE35895A
            value: 201003,10004,90.3924,23.7485
    */

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String line = value.toString();
      String[] datetime;
      String uid = null, date = null, time = null, ant10 = null, lon = null, lat = null;

      // 先頭行, 空行は集計対象外
      if (line.startsWith("uid") || line.trim().isEmpty()) {
        return;
      }

      StringTokenizer tokenizer = new StringTokenizer(line, "\t");
      for (int i=0; tokenizer.hasMoreTokens(); i++) {
        String s = tokenizer.nextToken();

        switch(i){
          // uid
          case 0:
            uid = s.trim();
            break;
          // datetime
          case 1:
            time = s.trim();
            // date, timeに分割. e.g. 2016-08-29, 23:42:30
            datetime = s.split(" ", 0);
            date = datetime[0].replace("-", "");
            time = datetime[1].replace(":", "");
            break;
          // ant10
          case 4:
            ant10 = s.trim();
            break;
          // lon
          case 5:
            lon = s.trim();
            break;
          // lat
          case 6:
            lat = s.trim();
            break;
        }
      }

      // lon, latがそれぞれ数値でない場合を除外(e.g. NULL)
      try {
        float lon_float = Float.parseFloat(lon);
        float lat_float = Float.parseFloat(lat);

        String map_key = String.format("%s,%s", uid, date);
        String map_value = String.format("%s,%s,%s,%s", time, ant10, lon, lat);
        context.write(new Text(map_key), new Text(map_value));
      }
      catch(NumberFormatException e){}
    }
  }

  // 1st Combiner
  public static class Combiner1 extends Reducer<Text, Text, Text, Text> {
    /* 
    処理はReducerとほぼ同様. 
    5〜10時/10時〜15時の間で最も早い/遅いvalueだけをそのまま返す.
    */
    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      int time, ant10;
      int earliest_time = 240000;
      int latest_time = 0;

      String[] value_list;
      String earliest_ant10 = null, earliest_lon = null, earliest_lat = null;
      String latest_ant10 = null, latest_lon = null, latest_lat = null;

      // 5時<=time<10時の間に最初にアクセスしたアンテナ, 
      // 10時<=time<15時の間に最後にアクセスしたアンテナを求める
      for(Text value : values){
        value_list = value.toString().split(",", 0);
        time = Integer.parseInt(value_list[0]);

        if(time >= 50000 && time < 100000){
          if(time < earliest_time){
            earliest_time = time;
            earliest_ant10 = value_list[1];
            earliest_lon = value_list[2];
            earliest_lat = value_list[3];
          }
        }

        if(time >= 100000 && time < 150000){
          if(time > latest_time){
            latest_time = time;
            latest_ant10 = value_list[1];
            latest_lon = value_list[2];
            latest_lat = value_list[3];
          }
        }
      }

      if(earliest_ant10 != null){
        String output_value = String.format(
          "%d,%s,%s,%s", earliest_time, earliest_ant10, earliest_lon, earliest_lat);
        context.write(key, new Text(output_value));
      }

      if(latest_ant10 != null){
        String output_value = String.format(
          "%d,%s,%s,%s", latest_time, latest_ant10, latest_lon, latest_lat);
        context.write(key, new Text(output_value));
      }
    }
  }

  // 1st Reducer
  public static class Reducer1 extends Reducer<Text, Text, Text, Text> {
    /* 
      1. 同日内に同じユーザーが5:00~10:00までに1回以上アクセス(originが存在)
      2. 同日内に同じユーザーが に10:00~15:00までに1回以上アクセス(destinationが存在)
      の両方を満たした場合, 1を満たす最も早い時間のアンテナをorigin, 2を満たすもっとも
      遅い時間のアンテナをdestinationとして, <uid+date, time+ant10+lon+lat> 

      -> <userid+date, origin_ant10+origin_lon+origin_lat+
            destination_ant10+destination_lon+destination_lat> 
      にreduce
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      int time, ant10;
      int earliest_time = 240000;
      int latest_time = 0;

      String[] value_list;
      String earliest_ant10 = null, earliest_lon = null, earliest_lat = null;
      String latest_ant10 = null, latest_lon = null, latest_lat = null;

      // 5時<=time<10時の間に最初にアクセスしたアンテナ, 
      // 10時<=time<15時の間に最後にアクセスしたアンテナを求める
      for(Text value : values){
        value_list = value.toString().split(",", 0);
        time = Integer.parseInt(value_list[0]);

        if(time >= 50000 && time < 100000){
          if(time < earliest_time){
            earliest_time = time;
            earliest_ant10 = value_list[1];
            earliest_lon = value_list[2];
            earliest_lat = value_list[3];
          }
        }

        if(time >= 100000 && time < 150000){
          if(time > latest_time){
            latest_time = time;
            latest_ant10 = value_list[1];
            latest_lon = value_list[2];
            latest_lat = value_list[3];
          }
        }
      }

      if(earliest_ant10 != null && latest_ant10 != null){
        String output_value = String.format(
          "%s,%s,%s,%s,%s,%s", 
          earliest_ant10, earliest_lon, earliest_lat, 
          latest_ant10, latest_lon, latest_lat
          );
        context.write(key, new Text(output_value));
      }
    }
  }

  // Writer
  public static class CommaTextOutputFormat extends TextOutputFormat<Text, Text> {
    @Override
    public RecordWriter<Text, Text> getRecordWriter(TaskAttemptContext job) throws IOException, InterruptedException {
      Configuration conf = job.getConfiguration();
      String extension = ".txt";
      Path file = getDefaultWorkFile(job, extension);
      FileSystem fs = file.getFileSystem(conf);
      FSDataOutputStream fileOut = fs.create(file, false);
      return new LineRecordWriter<Text, Text>(fileOut, ",");
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "commuting panel1");

    if (args.length != 3) {
      System.err.println("Need 3 arguments: <input file> <output file> <month>");
      System.exit(1);
    }

    String input_path = args[0];
    String output_path = args[1];
    String month = args[2];

    String file_name_base = String.format("commuting-%s", month);
    job.getConfiguration().set("mapreduce.output.basename", file_name_base);

    // general
    job.setJarByClass(CommutingPanel1.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Combiner1.class);
    job.setReducerClass(Reducer1.class);
    job.setNumReduceTasks(2);
    job.setInputFormatClass (TextInputFormat.class);
    
    // mapper output
    job.setMapOutputKeyClass(Text.class);
    job.setMapOutputValueClass(Text.class);
    
    // reducer output
    job.setOutputFormatClass(CommaTextOutputFormat.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(Text.class);

    FileInputFormat.addInputPath(job, new Path(input_path));
    FileOutputFormat.setOutputPath(job, new Path(output_path));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}

