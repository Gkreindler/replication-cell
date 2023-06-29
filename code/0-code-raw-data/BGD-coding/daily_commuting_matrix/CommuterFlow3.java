// Output Commuter Flow Matrix By Day.

import java.io.IOException;
import java.util.StringTokenizer;
import java.io.DataInput; 
import java.io.DataOutput; 
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;

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

public class CommuterFlow3 {

  // 2nd Mapper
  public static class Mapper3 extends Mapper<LongWritable, Text, Text, IntWritable> {
    /* 
      <date_antcodes, 1> の組にmap. 
    */

    private Text date_antcodes = new Text();
    private static final IntWritable one = new IntWritable(1);

    
    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String line = value.toString();
      String key_raw = "";

      Configuration conf = context.getConfiguration();
      int set_date = Integer.parseInt(conf.get("set_date"));
      int line_date = 0;

      // 空行は集計対象外
      if (line.trim().isEmpty()) {
        return;
      }

      StringTokenizer tokenizer = new StringTokenizer(line, ",");
      for(int i=0; tokenizer.hasMoreTokens(); i++){
        String s = tokenizer.nextToken();
        
        // date
        if(i==0){
          line_date = Integer.parseInt(s.trim());
          if(line_date != set_date){
            break;
          }
          key_raw += line_date + ",";
        }
        // antcode_from
        if(i==1){
          key_raw += s.trim() + ",";
        }

        // antcode_to
        if(i==2){
          key_raw += s.trim();
          date_antcodes.set(key_raw);
          context.write(date_antcodes, one);
          break;
        }
      }
    }
  }

  // 2nd Reducer
  public static class Reducer3 extends Reducer<Text, IntWritable, Text, IntWritable> {
    /* antcodes毎にsumを求める */
    private IntWritable sum_r = new IntWritable();

    @Override
    protected void reduce(Text date_antcodes, Iterable<IntWritable> vals, Context context) throws IOException, InterruptedException {
      int sum = 0;

      for(IntWritable val : vals){
        sum += 1;
      }

      sum_r.set(sum);
      context.write(date_antcodes, sum_r);
    }
  }

  // Writer
  public static class CommaTextOutputFormat extends TextOutputFormat<Text, IntWritable> {
    @Override
    public RecordWriter<Text, IntWritable> getRecordWriter(TaskAttemptContext job) throws IOException, InterruptedException {
      Configuration conf = job.getConfiguration();
      String extension = ".txt";
      Path file = getDefaultWorkFile(job, extension);
      FileSystem fs = file.getFileSystem(conf);
      FSDataOutputStream fileOut = fs.create(file, false);
      return new LineRecordWriter<Text, IntWritable>(fileOut, ",");
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();

    if (args.length != 3) {
      System.err.println("Need 3 arguments: <input dir> <output base dir> <year_month>");
      System.exit(1);
    }

    Path input_path = new Path(args[0]);
    Path output_path = null;
    int year_month = new Integer(args[2]);
    int num_of_dates = 0;

    switch(year_month){
      case 201308:
        num_of_dates = 31;
        break;
      
      case 201309: 
        num_of_dates = 30;
        break;
      
      case 201311:
        num_of_dates = 30;
        break;
      
      case 201312:
        num_of_dates = 31;
        break;
      
      default:
        System.err.println("<year_month> must be 201308, 09, 11 or 12.");
        System.exit(1);
    }

    // 各日付に対してmapreduceを実行
    for(int i=1; i<=num_of_dates; i++){
      String d = String.format("%02d", i);
      String ymd = year_month + d;
      conf.set("set_date", ymd); // 日付をmapper, reducerに渡す
      output_path = new Path(args[1] + "/" + ymd + "/");
      
      Job job = Job.getInstance(conf, "commuter flow3: " + year_month);

      // general settings
      job.setJarByClass(CommuterFlow3.class);
      job.setMapperClass(Mapper3.class);
      job.setReducerClass(Reducer3.class);
      job.setNumReduceTasks(2);
      job.setInputFormatClass (TextInputFormat.class);
      
      // mapper output settings
      job.setMapOutputKeyClass(Text.class);
      job.setMapOutputValueClass(IntWritable.class);
      
      // reducer output settings
      job.setOutputFormatClass(CommaTextOutputFormat.class);
      job.setOutputKeyClass(Text.class);
      job.setOutputValueClass(IntWritable.class);

      // formatter settings
      FileInputFormat.addInputPath(job, input_path);
      FileOutputFormat.setOutputPath(job, output_path);

      if(!job.waitForCompletion(true)){
        System.exit(1);
      }
    }
    System.out.println("All Finished");
    System.exit(0);
  }
}