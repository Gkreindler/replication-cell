package tripsMinMax;

//import main.java.*;

import java.io.IOException;
import java.util.*;
import java.util.Calendar.*;

import org.apache.hadoop.fs.Path;
import org.apache.hadoop.conf.*;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapred.*;
import org.apache.hadoop.util.*;


import utilities.DScsvReader;
import utilities.PublicHolidaycsvReader;


/**
* This Hadoop class will take output from TripsMinMax (individual daily min-max trips) and combine it at the tower_source,tower_destination level
 * 
 * Example output line: 1000000984,130701	2823,2823
 * Description: ID, YYMMDD <-Tab-> Tower ID origin, Tower ID destination
 * 
 * Example output line: 2823,2823,130701 <tab> 4325
 * Description: Tower ID origin, Tower ID destination, YYMMDD <tab> count
 * 
 * @author Gabriel Kreindler
 * @date   23 august 2014
 */

public class TripsMinMaxCombine {

	public static class Map extends MapReduceBase implements
			Mapper<LongWritable, Text, Text, IntWritable> {
		private final static IntWritable one = new IntWritable(1);
		 	
		 	public void map(LongWritable key, Text value, OutputCollector<Text, IntWritable> output, Reporter reporter) throws IOException {
		 		String line = value.toString();
				String[] parts=line.split("\\\t");
				
				String[] keyparts =parts[0].split("\\,");
				
				// key = TowerID_origin, TowerID_dest, YYMMDD
				// values = 1 (count)
				output.collect( new Text(parts[1] + "," + keyparts[1]) , one );
				
			// end map	
		 	 }
	}

	public static class Reduce extends MapReduceBase implements Reducer<Text, IntWritable, Text, IntWritable> {
		
			public void reduce(Text key, Iterator<IntWritable> values, OutputCollector<Text, IntWritable> output, Reporter reporter) throws IOException {
				
				int ntrips = 0;
		 		
				while (values.hasNext()) {
		 		ntrips += values.next().get();
		 		}
		 			
		 		output.collect(key, new IntWritable(ntrips));	
				
		  //end reduce
		 }
	}

	public static void main(String[] args) throws Exception {
		JobConf conf = new JobConf(TripsMinMaxCombine.class);
		conf.setJobName("TripsMinMaxCombine");
		conf.setNumReduceTasks(3);

		conf.setOutputKeyClass(Text.class);
		conf.setOutputValueClass(IntWritable.class);
		conf.setMapperClass(Map.class);
		conf.setCombinerClass(Reduce.class);
		conf.setReducerClass(Reduce.class);

		conf.setInputFormat(TextInputFormat.class);
		conf.setOutputFormat(TextOutputFormat.class);

		FileInputFormat.setInputPaths(conf, new Path(args[0]));
		FileOutputFormat.setOutputPath(conf, new Path(args[1]));

		JobClient.runJob(conf);
	}
}