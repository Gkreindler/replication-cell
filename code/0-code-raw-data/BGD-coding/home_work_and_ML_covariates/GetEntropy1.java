/* GetEntropy1.java

各ユーザーごとに, 以下を抽出
- 総サンプル期間内にいくつの（unique）アンテナにアクセスしたか
- centroid（重心）
- gyration (sum of the squared distances from the centroid)
- entropy of places

input: userid, tower, home_work_dummy, count
output: userid, num_unique_towers, num_total_count, centroid_lon, centroid_lat, gyration, entropy
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
import java.lang.Math;

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

public class GetEntropy1 {

  public static HashMap<Integer, Double> tower_lon_table = new HashMap<Integer, Double>();
  public static HashMap<Integer, Double> tower_lat_table = new HashMap<Integer, Double>();
  public static double EARTH_RADIUS = 6378.137;

  // 1st Mapper
  public static class Mapper1 extends Mapper<LongWritable, Text, Text, Text> {
    /* <uid, tower+count+lon+lat> の組にmap.
    */

    public void setup(Context context) throws IOException, InterruptedException {
      Configuration conf = context.getConfiguration();
      read_lon_lat_table(conf.get("lon_lat_table_path"));
    }

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
      String[] line = value.toString().split(",", 0);

      try {
        if (line[1] != null) {
          int tower = Integer.parseInt(line[1]);
          int count = Integer.parseInt(line[3]);
          double lon = tower_lon_table.get(tower);
          double lat = tower_lat_table.get(tower);

          String map_value = String.format("%d,%d,%f,%f", tower, count, lon, lat);
          context.write(new Text(line[0]), new Text(map_value));
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
      output: <userid, num_unique_towers, num_total_count, centroid_lon, centroid_lat, gyration, entropy>
      
      1. <tower, count+lon+lat> の組にreduce. num_unique_towers, centroid, num_total_countを計算
      2. gyration, entropyを計算
    */

    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
      int num_unique_towers = 0, num_total_count = 0;
      double centroid_lon = 0, centroid_lat = 0, gyration = 0, entropy = 0;
      HashMap<Integer, Integer> tower_count = new HashMap<Integer, Integer>();
      HashMap<Integer, Double> tower_lon = new HashMap<Integer, Double>();
      HashMap<Integer, Double> tower_lat = new HashMap<Integer, Double>();
      
      for(Text value : values){
        String[] value_text = value.toString().split(",", 0);
        int tower = Integer.parseInt(value_text[0]);
        int count = Integer.parseInt(value_text[1]);
        double lon = Double.parseDouble(value_text[2]);
        double lat = Double.parseDouble(value_text[3]);

        if (tower_count.containsKey(tower)) {
          tower_count.put(tower, tower_count.get(tower) + count);
          num_unique_towers += 1;
        } else {
          tower_count.put(tower, count);
          tower_lon.put(tower, lon);
          tower_lat.put(tower, lat);
        }

        num_total_count += count;
        centroid_lon += count * lon;
        centroid_lat += count * lat;
      }

      centroid_lon /= num_total_count;
      centroid_lat /= num_total_count;

      for (Integer tower : tower_count.keySet()) {
        int count = tower_count.get(tower);
        double lon = tower_lon.get(tower);
        double lat = tower_lat.get(tower);
        gyration += count * Math.pow(get_dist(centroid_lon, centroid_lat, lon, lat), 2);
        double prob = (double)count / num_total_count;
        entropy += -1 * prob * Math.log(prob);
      }

      String map_value = String.format(
        "%d,%d,%.4f,%.4f,%.4f,%.4f", 
        num_unique_towers, 
        num_total_count, 
        centroid_lon, 
        centroid_lat, 
        gyration, 
        entropy
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

  // Read lon lat table
  public static void read_lon_lat_table(String path_str) {
    try (BufferedReader br = Files.newBufferedReader(Paths.get(path_str))) {
      String line;
      String[] line_array;
      // skip header
      br.readLine();
      while ((line = br.readLine()) != null) {
        line_array = line.split(",");
        tower_lon_table.put(
          Integer.parseInt(line_array[0]), 
          Double.parseDouble(line_array[2])
        );
        tower_lat_table.put(
          Integer.parseInt(line_array[0]), 
          Double.parseDouble(line_array[3])
        );
      }
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading lon lat table");
  }

  // Get the distance between two points
  public static double get_dist(Double lon_1, Double lat_1, Double lon_2, Double lat_2) {
    double ant1_lon_rad = lon_1 * Math.PI / 180;
    double ant1_lat_rad = lat_1 * Math.PI / 180;
    double ant2_lon_rad = lon_2 * Math.PI / 180;
    double ant2_lat_rad = lat_2 * Math.PI / 180;
    double x1 = Math.cos(ant1_lat_rad) * Math.cos(ant1_lon_rad);
    double y1 = Math.cos(ant1_lat_rad) * Math.sin(ant1_lon_rad);
    double z1 = Math.sin(ant1_lat_rad);
    double x2 = Math.cos(ant2_lat_rad) * Math.cos(ant2_lon_rad);
    double y2 = Math.cos(ant2_lat_rad) * Math.sin(ant2_lon_rad);
    double z2 = Math.sin(ant2_lat_rad);
    double angle = Math.acos(x1 * x2 + y1 * y2 + z1 * z2);

    return EARTH_RADIUS * angle;
  }

  
  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();

    if (args.length != 3) {
      System.err.println("Need 3 arguments: <input dir> <output dir> <lon_lat_table_path>");
      System.exit(1);
    }

    String input_dir = args[0];
    String output_dir = args[1];

    // pass arguments to mapper
    conf.set("lon_lat_table_path", args[2]);

    Job job = Job.getInstance(conf, "get_entropy_1");
    job.getConfiguration().set("mapreduce.output.basename", "entropy");

    // general
    job.setJarByClass(GetEntropy1.class);
    job.setMapperClass(Mapper1.class);
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

