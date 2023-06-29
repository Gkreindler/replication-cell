/* GetHomeOffice3.java

各日時・アンテナ・ユーザーid別に, 何回アンテナにアクセスしているかをカウント

input: CBD
output: tower, date, hour, uid, total_count, total_duration, duration_count

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

public class GetHomeOffice3 {

  public static HashMap<Integer, Integer> ant_conversion_table = new HashMap<Integer, Integer>();

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, Text> {
    /* <tower+date+hour+uid, count+duration+duration_count> の組にmap.
       e.g. key: 232,20130701,22,22B2F03DB6FCE5B376B897A3CE35895A
            value: 1,23,1
    */

    public void setup(Context context) throws IOException, InterruptedException {
      Configuration conf = context.getConfiguration();
      read_conversion_table(conf.get("conversion_table_path"));
    }

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String line = value.toString();
      String[] datetime, date_list;
      String uid = null, date_str = null;
      Integer date = -1, hour = -1, ant10, tower = -1, home_tower = -1, office_tower = -1;
      Integer duration = 0, duration_count = 0;
      Float home_min, office_min;

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
            // date, timeに分割. e.g. 2016-08-29, 23:42:30
            datetime = s.trim().split(" ", 0);
            date = Integer.parseInt(datetime[0].replace("-", ""));
            hour = Integer.parseInt(datetime[1].substring(0, 2));
            break;

          // duration
          case 2:
            // -1はNULLとして扱う
            duration = Integer.parseInt(s);
            if (duration < 0) {
              duration = 0;
              duration_count = 0;
            } else {
              duration_count = 1;
            }
          
          // ant10
          case 4:
            ant10 = Integer.parseInt(s.trim());
            tower = ant_conversion_table.get(ant10);
            break;
        }
      }

      try {
        if (tower != null) {
          String map_key = String.format("%d,%d,%d,%s", tower, date, hour, uid);
          String map_value = String.format("1,%d,%d", duration, duration_count);
          context.write(new Text(map_key), new Text(map_value));
        }
      }
      catch(NumberFormatException e){
        System.out.println("Error");
        System.out.println(value.toString());
      }
    }
  }

  // 1st Reducer
  public static class Reducer1 extends Reducer<Text, Text, Text, Text> {
    /*
      回数の和を取り
      -> <tower, date, hour, uid, total_count>
      にreduce
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      Integer count = 0, duration = 0, duration_count = 0;
      
      for(Text value : values){
        String[] value_text = value.toString().split(",", 0);
        count += Integer.parseInt(value_text[0]);
        duration += Integer.parseInt(value_text[1]);
        duration_count += Integer.parseInt(value_text[2]);
      }

      String map_value = String.format("%d,%d,%d", count, duration, duration_count);
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

  // Read ant10 convert table
  public static void read_conversion_table(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        ant_conversion_table.put(
          Integer.parseInt(line_array[1]), 
          Integer.parseInt(line_array[0])
        );
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading ant conversion table");
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();

    if (args.length != 3) {
      System.err.println("Need 3 arguments: <input dir> <output dir> <conversion_table_path>");
      System.exit(1);
    }

    String input_dir = args[0];
    String output_dir = args[1];

    // pass arguments to mapper
    conf.set("conversion_table_path", args[2]);

    Job job = Job.getInstance(conf, "get_home_office_3");
    job.getConfiguration().set("mapreduce.output.basename", "home_office_count");

    // general
    job.setJarByClass(GetHomeOffice3.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Reducer1.class);
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

