/* GetHomeOffice1.java

各userid毎に, 自宅と会社の位置をアンテナタワー単位で抽出する. 詳細はREADME

input: CBD
output: userid, tower, home_work_dummy, count

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
import java.time.LocalDateTime;
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

public class GetHomeOffice1 {

  public static HashMap<Integer, Integer> conversion_table = new HashMap<Integer, Integer>();
  public static ArrayList<Integer> hartal_list = new ArrayList<>();
  public static ArrayList<Integer> holiday_list = new ArrayList<>();

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, IntWritable> {
    /* <uid+tower+home_work_dummy, count> の組にmap. home_work_dummy==1 if it indicates an office.
       e.g. key: 22B2F03DB6FCE5B376B897A3CE35895A,232,1
            value: 1
    */

    public void setup(Context context) throws IOException, InterruptedException {
      Configuration conf = context.getConfiguration();
      read_conversion_table(conf.get("conversion_table_path"));
      read_hartal_list(conf.get("hartal_list_path"));
      read_holiday_list(conf.get("holiday_list_path"));
    }

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String line = value.toString();
      String[] datetime, date_list;
      String uid = null, date_str = null;
      Integer date, time, ant10, tower = -1, home_work_dummy = -1, count = 0;
      LocalDateTime ldate;

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
            time = Integer.parseInt(datetime[1].replace(":", ""));

            if (time < 50000) {
              date_list = datetime[0].split("-", 0);
              ldate = LocalDateTime.of(
                Integer.parseInt(date_list[0]),
                Integer.parseInt(date_list[1]),
                Integer.parseInt(date_list[2]), 
                0, 0, 0
              ).plusDays(-1);
              date = Integer.parseInt(
                ldate.format(DateTimeFormatter.ofPattern("uuuuMMdd"))
              );
            } else {
              date = Integer.parseInt(datetime[0].replace("-", ""));
            }
            
            if (!holiday_list.contains(date) && !hartal_list.contains(date)) {
              if (time < 50000) {
                home_work_dummy = 0; 
              } 
              else if (time > 100000 && time <= 150000) {
                home_work_dummy = 1;
              }
              else if (time >= 210000) {
                home_work_dummy = 0;
              } 
              else {
                home_work_dummy = -1;
              }
            }
            break;
          
          // ant10
          case 4:
            ant10 = Integer.parseInt(s.trim());
            tower = conversion_table.get(ant10);
            break;
        }
      }

      try {
        if (home_work_dummy != -1 && tower != null) {
          String map_key = String.format("%s,%d,%d", uid, tower, home_work_dummy);
          Integer map_value = 1;
          context.write(new Text(map_key), new IntWritable(map_value));
        }
      }
      catch(NumberFormatException e){
        System.out.println("Error");
        System.out.println(value.toString());
      }
    }
  }

  // 1st Reducer
  public static class Reducer1 extends Reducer<Text, IntWritable, Text, IntWritable> {
    /*
      回数の和を取り
      -> <uid, tower, home_work_dummy, count> 
      にreduce
    */

    @Override
    protected void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
      Integer count = 0;
      for(IntWritable value : values){
        count += value.get();
      }
      context.write(key, new IntWritable(count));
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
        conversion_table.put(
          Integer.parseInt(line_array[1]), 
          Integer.parseInt(line_array[0])
        );
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading conversion table");
  }

  // Read hartal list
  public static void read_hartal_list(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        hartal_list.add(
          Integer.parseInt(line_array[0])
        );
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading hartal list");
  }

  // Read holiday list
  public static void read_holiday_list(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        holiday_list.add(
          Integer.parseInt(line_array[0])
        );
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading holiday list");
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();

    if (args.length != 5) {
      System.err.println("Need 5 arguments: <input dir> <output dir> <conversion_table_path> <hartal_list_path> <holiday_list_path>");
      System.exit(1);
    }

    String input_dir = args[0];
    String output_dir = args[1];

    // pass arguments to mapper
    conf.set("conversion_table_path", args[2]);
    conf.set("hartal_list_path", args[3]);
    conf.set("holiday_list_path", args[4]);

    Job job = Job.getInstance(conf, "get_home_office_1");
    job.getConfiguration().set("mapreduce.output.basename", "home_office_count");

    // general
    job.setJarByClass(GetHomeOffice1.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Reducer1.class);
    job.setReducerClass(Reducer1.class);
    job.setNumReduceTasks(2);
    job.setInputFormatClass(TextInputFormat.class);
    
    // mapper output
    job.setMapOutputKeyClass(Text.class);
    job.setMapOutputValueClass(IntWritable.class);
    
    // reducer output
    job.setOutputFormatClass(CommaTextOutputFormat.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);

    FileInputFormat.addInputPath(job, new Path(input_dir));
    FileOutputFormat.setOutputPath(job, new Path(output_dir));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}

