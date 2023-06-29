/* GetHomeOffice2.java

各userid毎に, 自宅と会社の位置をアンテナタワー単位で抽出する. 詳細はREADME

input: userid, tower, home_work_dummy, count
output: userid, home_work_dummy（0だとhome, 1だとwork）, Tmax（最頻のタワー）, 
  Tmaxfreq（最大のタワーのトランザクション数）, totfreq（総トランザクション数）

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

public class GetHomeOffice2 {

  public static HashMap<Integer, Integer> conversion_table = new HashMap<Integer, Integer>();
  public static ArrayList<Integer> hartal_list = new ArrayList<>();
  public static ArrayList<Integer> holiday_list = new ArrayList<>();

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, Text> {
    /* <uid+home_work_dummy, tower+Tmaxfreq+totfreq> の組にmap. home_work_dummy==1 if it indicates an office.
       e.g. key: 22B2F03DB6FCE5B376B897A3CE35895A,1
            value: 232,1,1
    */

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String[] line = value.toString().split(",", 0);

      try {
        String map_key = String.format("%s,%s", line[0], line[2]);
        String map_value = String.format("%s,%s,%s", line[1], line[3], line[3]);
        context.write(new Text(map_key), new Text(map_value));
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
      userid, home_work_dummy, tmax, tmaxfreq, totfreq
      にreduce
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      Integer count, totfreq = 0, tmax = -1, tmaxfreq = -1;
      String[] line;
      for(Text value : values){
        line = value.toString().split(",", 0);
        count = Integer.parseInt(line[1]);
        totfreq += Integer.parseInt(line[2]);
        if (count > tmaxfreq) {
          tmaxfreq = count;
          tmax = Integer.parseInt(line[0]);
        }
      }
      String map_value = String.format("%d,%d,%d", tmax, tmaxfreq, totfreq);
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

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "get_home_office_2");

    if (args.length != 2) {
      System.err.println("Need 2 arguments: <input dir> <output dir>");
      System.exit(1);
    }

    String input_dir = args[0];
    String output_dir = args[1];
    
    job.getConfiguration().set("mapreduce.output.basename", "home_office");

    // general
    job.setJarByClass(GetHomeOffice2.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Reducer1.class);
    job.setReducerClass(Reducer1.class);
    job.setNumReduceTasks(1);
    job.setInputFormatClass (TextInputFormat.class);
    
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

