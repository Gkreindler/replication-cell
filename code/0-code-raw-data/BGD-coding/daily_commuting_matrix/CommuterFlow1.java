import java.io.IOException;
import java.util.StringTokenizer;
import java.io.DataInput; 
import java.io.DataOutput; 
import java.util.ArrayList;
import java.util.List;

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

public class CommuterFlow1 {

  // Time
  public static class Time implements Writable { 
    private int h, m, s;

    public Time() {}

    public Time(int h, int m, int s) {
      this.h = h;
      this.m = m;
      this.s = s;
    }

    public Time(String time) {
      String[] hms = time.split(":", 0);
      this.h = Integer.parseInt(hms[0]);
      this.m = Integer.parseInt(hms[1]);
      this.s = Integer.parseInt(hms[2]);
    }

    public void set(int h, int m, int s) {
      this.h = h;
      this.m = m;
      this.s = s;
    }

    public void set(String time) {
      String[] hms = time.split(":", 0);
      this.h = Integer.parseInt(hms[0]);
      this.m = Integer.parseInt(hms[1]);
      this.s = Integer.parseInt(hms[2]);
    }

    public int[] getTime() {
      int[] time = new int[3];
      time[0] = this.h;
      time[1] = this.m;
      time[2] = this.s;
      return time;
    }

    public String getTimeStr() {
      return String.format("%1$02d:%2$02d:%3$02d", this.h, this.m, this.s);
    }

    public int getTimeInt() {
      return this.h * 10000 + this.m * 100 + this.s;
    }

    @Override
    public void readFields(DataInput in) throws IOException {
      h = in.readInt();
      m = in.readInt();
      s = in.readInt();
    }

    @Override
    public void write(DataOutput out) throws IOException {
      out.writeInt(h);
      out.writeInt(m);
      out.writeInt(s);
    }
  }

  // TimeとAnt10のCompositeWritable
  public static class Time_Ant10 implements Writable { 
    private Time time = new Time();
    private int ant10;

    public Time_Ant10() {
      this.time = new Time();
    }

    public Time_Ant10(Time time, int ant10) {
      this.time = time;
      this.ant10 = ant10;
    }

    public Time_Ant10(String time, int ant10) {
      this.time = new Time(time);
      this.ant10 = ant10;
    }

    public void set(Time time, int ant10) {
      this.time = time;
      this.ant10 = ant10;
    }

    public void set(String time, int ant10) {
      this.time.set(time);
      this.ant10 = ant10;
    }

    public void set(int h, int m, int s, int ant10) {
      this.time.set(h, m, s);
      this.ant10 = ant10;
    }

    public int[] getTime() {
      return this.time.getTime();
    }

    public String getTimeStr() {
      return this.time.getTimeStr();
    }

    public int getTimeInt() {
      return this.time.getTimeInt();
    }

    public int getAnt10() {
      return this.ant10;
    }

    @Override
    public void readFields(DataInput in) throws IOException {
      time.readFields(in);
      ant10 = in.readInt();
    }

    @Override
    public void write(DataOutput out) throws IOException {
      time.write(out);
      out.writeInt(ant10);
    }
  }

  // DateとuidのCompositeWritableComparable
  public static class Date_Uid implements WritableComparable<Date_Uid> { 
    private String uid = null;
    private int date;

    public Date_Uid() {
      this.uid = new String();
      this.date = -1;
    }

    public Date_Uid(String uid, int date) {
      this.uid = uid;
      this.date = date;
    }

    public void set(String uid, int date) {
      this.uid = uid;
      this.date = date;
    }

    public int getDate() {
      return this.date;
    }

    public String getUid() {
      return this.uid;
    }

    @Override
    public int compareTo(Date_Uid that) {
      int c = this.date - that.date;
      if (c != 0) {
        return c;
      }
      return uid.compareTo(that.uid);
    }

    @Override
    public void readFields(DataInput in) throws IOException {
      uid = in.readUTF();
      date = in.readInt();
    }

    @Override
    public void write(DataOutput out) throws IOException {
      out.writeUTF(uid);
      out.writeInt(date);
    }
  }

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Date_Uid, Time_Ant10> {
    /* <date_uid, time_ant10> の組にmap 
       e.g. date_uid = (20160821, 22B2F03DB6FCE5B376B897A3CE35895A)
            time_ant10 = (20:10:03, 1121)
    */
    private Time_Ant10 time_ant10 = new Time_Ant10();
    private Date_Uid date_uid = new Date_Uid();
    
    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String line = value.toString();
      String[] datetime;
      String uid = null, time = null;
      int date = -1, ant10 = -1;

      // 先頭行, 空行は集計対象外
      if (line.startsWith("uid") || line.trim().isEmpty()) {
        return;
      }

      StringTokenizer tokenizer = new StringTokenizer(line, "\t");
      for (int i=0; tokenizer.hasMoreTokens(); i++) {
        String s = tokenizer.nextToken();
        // uid
        if (i==0) {
          uid = s.trim();
        }
        // datetime
        else if (i==1){
          time = s.trim();
          // date, timeに分割
          // e.g. 2016-08-29, 23:42:30
          datetime = s.split(" ", 0);
          date = Integer.parseInt(datetime[0].replace("-", ""));
          time = datetime[1];
        }
        // ant10
        else if (i==4){
          ant10 = Integer.parseInt(s.trim());
          time_ant10.set(time, ant10);
          date_uid.set(uid, date);
          context.write(date_uid, time_ant10);
          break;
        }
      }
    }
  }

  // 1st Combiner
  public static class Combiner1 extends Reducer<Date_Uid, Time_Ant10, Date_Uid, Time_Ant10> {
    /* 処理はReducerとほぼ同様. 5〜10時/10時〜15時の間で最も早い/遅いTime_Ant10をそのまま返す.*/
    private IntWritable key = new IntWritable();
    private Text ant_from_to = new Text();

    @Override
    protected void reduce(Date_Uid date_uid, Iterable<Time_Ant10> time_ant10s, Context context) throws IOException, InterruptedException {
      Time_Ant10 time_ant10_from = new Time_Ant10();
      Time_Ant10 time_ant10_to = new Time_Ant10();
      int time, ant10;

      int earliest_time = 240000;
      int latest_time = 0;

      int earliest_ant = -1;
      int latest_ant = -1;

      // output key
      key.set(date_uid.getDate());

      // 5時<=time<10時の間に最初にアクセスしたアンテナ, 10時<=time<15時の間に最後にアクセスしたアンテナを求める
      for(Time_Ant10 time_ant10 : time_ant10s){
        time = time_ant10.getTimeInt();
        ant10 = time_ant10.getAnt10();

        if(time >= 50000 && time < 100000){
          if(time < earliest_time){
            earliest_time = time;
            earliest_ant = ant10;
            time_ant10_from.set(time/10000, (time%10000)/100, time%100, ant10);
          }
        }

        if(time >= 100000 && time < 150000){
          if(time > latest_time){
            latest_time = time;
            latest_ant = ant10;
            time_ant10_to.set(time/10000, (time%10000)/100, time%100, ant10);
          }
        }
      }

      if(latest_ant != -1){
        context.write(date_uid, time_ant10_to);
      }

      if(earliest_ant != -1){
        context.write(date_uid, time_ant10_from);
      }
    }
  }

  // 1st Reducer
  public static class Reducer1 extends Reducer<Date_Uid, Time_Ant10, IntWritable, Text> {
    /* 以下の条件を満たした場合, <date_uid, time_ant10> -> <date, 1> にreduce
      
      1. 同日内に同じユーザーが {commute_start_ants} に5:00~10:00までに1回以上アクセス
      2. 同日内に同じユーザーが {commute_end_ants} に10:00~15:00までに1回以上アクセス
    */
    private IntWritable key = new IntWritable();
    private Text ant_from_to = new Text();

    @Override
    protected void reduce(Date_Uid date_uid, Iterable<Time_Ant10> time_ant10s, Context context) throws IOException, InterruptedException {
      int time, ant10;

      int earliest_time = 240000;
      int latest_time = 0;

      int earliest_ant = -1;
      int latest_ant = -1;

      // output key
      key.set(date_uid.getDate());

      // 5時<=time<10時の間に最初にアクセスしたアンテナ, 10時<=time<15時の間に最後にアクセスしたアンテナを求める
      for(Time_Ant10 time_ant10 : time_ant10s){
        time = time_ant10.getTimeInt();
        ant10 = time_ant10.getAnt10();

        if(time >= 50000 && time < 100000){
          if(time < earliest_time){
            earliest_time = time;
            earliest_ant = ant10;
          }
        }

        if(time >= 100000 && time < 150000){
          if(time > latest_time){
            latest_time = time;
            latest_ant = ant10;
          }
        }
      }

      if(earliest_ant != -1 && latest_ant != -1){
        // output value
        ant_from_to.set("" + earliest_ant + "," + latest_ant);
        context.write(key, ant_from_to);
      }
    }
  }

  // Writer
  public static class CommaTextOutputFormat extends TextOutputFormat<IntWritable, Text> {
    @Override
    public RecordWriter<IntWritable, Text> getRecordWriter(TaskAttemptContext job) throws IOException, InterruptedException {
      Configuration conf = job.getConfiguration();
      String extension = ".txt";
      Path file = getDefaultWorkFile(job, extension);
      FileSystem fs = file.getFileSystem(conf);
      FSDataOutputStream fileOut = fs.create(file, false);
      return new LineRecordWriter<IntWritable, Text>(fileOut, ",");
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "commuter flow1");

    // general
    job.setJarByClass(CommuterFlow1.class);
    job.setMapperClass(Mapper1.class);
    job.setCombinerClass(Combiner1.class);
    job.setReducerClass(Reducer1.class);
    job.setNumReduceTasks(2);
    job.setInputFormatClass (TextInputFormat.class);
    
    // mapper output
    job.setMapOutputKeyClass(Date_Uid.class);
    job.setMapOutputValueClass(Time_Ant10.class);
    
    // reducer output
    job.setOutputFormatClass(CommaTextOutputFormat.class);
    job.setOutputKeyClass(IntWritable.class);
    job.setOutputValueClass(Text.class);

    FileInputFormat.addInputPath(job, new Path(args[0]));
    FileOutputFormat.setOutputPath(job, new Path(args[1]));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}