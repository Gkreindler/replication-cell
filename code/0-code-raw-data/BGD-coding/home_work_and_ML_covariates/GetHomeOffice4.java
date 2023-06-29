/* GetHomeOffice4.java

各日時・タワー毎に, 以下の情報を抽出する.
- 総トランザクション数
- 総ユニークユーザ数
- 家からの平均所要時間 (およびサンプルサイズ)
- 勤務地からの平均所要時間 (およびサンプルサイズ)
- 総通話時間

input: tower, date, hour, uid, total_count, total_duration, duration_count
output: tower, date, hour, totfreq, num_unique_users, 
  average_home_min, average_office_min, home_count, office_count, 
  total_duration, duration_count
*/

import java.io.IOException;
import java.util.StringTokenizer;
import java.io.DataInput; 
import java.io.DataOutput; 
import java.io.BufferedReader;
import java.util.stream.Stream;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Formatter;
import java.util.Map;
import java.util.HashMap;
import java.nio.file.Paths;
import java.nio.file.Files;
import java.time.format.DateTimeFormatter;

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

public class GetHomeOffice4 {

  public static HashMap<String, Integer> home_table = new HashMap<String, Integer>();
  public static HashMap<String, Integer> office_table = new HashMap<String, Integer>();
  public static HashMap<String, Double> min_list = new HashMap<String, Double>();

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, Text> {
    /* <tower+date+hour, totfreq+num_unique_users+home_min+office_min+home_count+office_count> の組にmap.
       e.g. key: 232,20130701,22
            value: 21,1,230.0,123.4,1,1
    */

    public void setup(Context context) throws IOException, InterruptedException {
      Configuration conf = context.getConfiguration();
      read_user_home_office_list(conf.get("user_home_office_table_path"));
      read_min_list(conf.get("min_list_path"));
    }

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String[] line_list = value.toString().split(",", 0);
      String map_key = String.format("%s,%s,%s", line_list[0], line_list[1], line_list[2]);
      Integer tower = Integer.parseInt(line_list[0]);
      String uid = line_list[3];
      int total_count = Integer.parseInt(line_list[4]);
      int total_duration = Integer.parseInt(line_list[5]);
      int duration_count = Integer.parseInt(line_list[6]);

      Integer home_tower = home_table.get(uid);
      Integer office_tower = office_table.get(uid);

      try {
        if (tower != null) {
          double home_min = 0.0;
          int home_count = 0;
          double office_min = 0.0;
          int office_count = 0;
          
          if (home_tower != null) {
            String dict_key_1 = String.format("%d,%d", tower, home_tower);
            String dict_key_2 = String.format("%d,%d", home_tower, tower);
            Double min_1 = min_list.get(dict_key_1);
            Double min_2 = min_list.get(dict_key_2);
            if (min_1 != null && min_2 != null) {
              home_min = (min_1 + min_2) / 2;
              home_count = 1;
            }
          }

          if (office_tower != null) {
            String dict_key_1 = String.format("%d,%d", tower, office_tower);
            String dict_key_2 = String.format("%d,%d", office_tower, tower);
            Double min_1 = min_list.get(dict_key_1);
            Double min_2 = min_list.get(dict_key_2);
            if (min_1 != null && min_2 != null) {
              office_min = (min_1 + min_2) / 2;
              office_count = 1;
            }
          }

          String map_value = String.format(
            "%d,%d,%f,%f,%d,%d,%d,%d", 
            total_count, 1, home_min, office_min, home_count, office_count, 
            total_duration, duration_count
          );
          context.write(new Text(map_key), new Text(map_value));
        }
      }
      catch(NumberFormatException e){
        System.out.println("Error");
        System.out.println(value.toString());
      }
    }
  }

  // 1st Combiner
  public static class Combiner1 extends Reducer<Text, Text, Text, Text> {
    /*
      totfreq, num_unique_users, home_min, office_min, home_count, office_count
      の和をそれぞれとる
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      double home_min = 0.0, office_min = 0.0;
      int home_count = 0, office_count = 0, totfreq = 0, num_unique_users = 0, total_duration = 0, duration_count = 0;
      
      for(Text value : values){
        String[] value_list = value.toString().split(",", 0);
        totfreq += Integer.parseInt(value_list[0]);
        num_unique_users += Integer.parseInt(value_list[1]);
        home_min += Double.parseDouble(value_list[2]);
        office_min += Double.parseDouble(value_list[3]);
        home_count += Integer.parseInt(value_list[4]);
        office_count += Integer.parseInt(value_list[5]);
        total_duration += Integer.parseInt(value_list[6]);
        duration_count += Integer.parseInt(value_list[7]);
      }

      String map_value = String.format(
        "%d,%d,%f,%f,%d,%d,%d,%d", 
        totfreq, num_unique_users, home_min, office_min, 
        home_count, office_count, total_duration, duration_count
      );
      context.write(key, new Text(map_value));
    }
  }

  // 1st Reducer
  public static class Reducer1 extends Reducer<Text, Text, Text, Text> {
    /*
      totfreq, num_unique_users, home_min, office_min, home_count, office_count の和を取り
      -> <tower, date, hour, totfreq, num_unique_users, 
        average_home_min, average_office_min, home_count, office_count> 
      にreduce
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      double home_min = 0, office_min = 0;
      int home_count = 0, office_count = 0, totfreq = 0, num_unique_users = 0, total_duration = 0, duration_count = 0;
      double average_home_min, average_office_min;
      
      for(Text value : values){
        String[] value_list = value.toString().split(",", 0);
        totfreq += Integer.parseInt(value_list[0]);
        num_unique_users += Integer.parseInt(value_list[1]);
        home_min += Double.parseDouble(value_list[2]);
        office_min += Double.parseDouble(value_list[3]);
        home_count += Integer.parseInt(value_list[4]);
        office_count += Integer.parseInt(value_list[5]);
        total_duration += Integer.parseInt(value_list[6]);
        duration_count += Integer.parseInt(value_list[7]);
      }

      if (home_count == 0) {
        average_home_min = 0;
      } else {
        average_home_min = home_min / home_count;
      }
      
      if (office_count == 0) {
        average_office_min = 0;
      } else {
        average_office_min = office_min / office_count;
      }

      String map_value = String.format(
        "%d,%d,%f,%f,%d,%d,%d,%d", 
        totfreq, num_unique_users, average_home_min, 
        average_office_min, home_count, office_count, 
        total_duration, duration_count
      );
      context.write(key, new Text(map_value));
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

  // Read user home office list
  public static void read_user_home_office_list(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      int home_work_dummy;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        home_work_dummy = Integer.parseInt(line_array[1]);

        if (home_work_dummy == 0) {
          home_table.put(
            line_array[0], 
            Integer.parseInt(line_array[2])
          );
        } else {
          office_table.put(
            line_array[0], 
            Integer.parseInt(line_array[2])
          );
        }
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading user home office list");
  }

  // Read min list
  public static void read_min_list(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      String key;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        key = line_array[0] + "," + line_array[1];
        
        if (line_array.length == 3) {
          String min_str = line_array[2].trim();
          if (min_str.length() > 0) {
            min_list.put(
              key, 
              Double.parseDouble(min_str)
            );
          }
        }
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading user home office list");
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();

    if (args.length != 4) {
      System.err.println("Need 4 arguments: <input dir> <output dir> <user_home_office_table_path> <min_list_path>");
      System.exit(1);
    }

    String input_dir = args[0];
    String output_dir = args[1];

    // pass arguments to mapper
    conf.set("user_home_office_table_path", args[2]);
    conf.set("min_list_path", args[3]);

    Job job = Job.getInstance(conf, "get_home_office_4");
    job.getConfiguration().set("mapreduce.output.basename", "home_office_count");

    // general
    job.setJarByClass(GetHomeOffice4.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Combiner1.class);
    job.setReducerClass(Reducer1.class);
    job.setNumReduceTasks(2);
    job.setInputFormatClass(TextInputFormat.class);
    
    // mapper output
    job.setMapOutputKeyClass(Text.class);
    job.setMapOutputValueClass(Text.class);
    
    // reducer output
    job.setOutputFormatClass(CommaTextOutputFormat.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(Text.class);

    FileInputFormat.addInputPath(job, new Path(input_dir));
    FileOutputFormat.setOutputPath(job, new Path(output_dir));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}

