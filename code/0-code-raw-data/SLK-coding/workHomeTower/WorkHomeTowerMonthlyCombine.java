package workHomeTower;

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
 * This Hadoop class will take output from WorkHomeTowerMonthly from different months (or groups of months) and combine at the ID,HomeWorkFlag key level
 * Program Arguments: <in> <out> 
 * 
 * Example input line: 651004263,0 <tab> 3432, 7
 * Description: ID, Home/Work (0=home) <tab> Tower code, number of call-days from that DS 
 * 
 * 
 * Example output line: 651004263,0 <tab> 4325, 20,30
 * Description: ID, Home/Work (0=home) <tab> maDS 4 digit code, number of call-days from that DS , total number of call-days
 * 
 * @author Gabriel Kreindler
 * 
 */

public class WorkHomeTowerMonthlyCombine {

	public static class Map extends MapReduceBase implements
			Mapper<LongWritable, Text, Text, Text> {
		private String ID;
		 	
		 	public void map(LongWritable key, Text value, OutputCollector<Text, Text> output, Reporter reporter) throws IOException {
		 		String line = value.toString();
				String[] parts=line.split("\\\t");
				
				// 0 = ID/hw , 1 = DS, freq
				output.collect( new Text(parts[0]) , new Text(parts[1]) );
				
			// end map	
		 	 }
	}

	public static class Reduce extends MapReduceBase implements Reducer<Text, Text, Text, Text> {
		private String  line, maxDS, maxDS2, currentDS;
		private Integer maxfreq, totfreq, maxfreq2, totfreq2, currentfreq;
		
			public void reduce(Text key, Iterator<Text> values, OutputCollector<Text, Text> output, Reporter reporter) throws IOException {
				
				HashMap<String, Integer> DScounts = new HashMap<String, Integer>();
				
		 		while (values.hasNext()) {
		 			line = values.next().toString();
		 			String[] parts = line.split("\\,");
		 			// 0 = DS, 1 = freq
		 			
		 			if(DScounts.containsKey(parts[0])){
		 				currentfreq = DScounts.get(parts[0]);;
		 				DScounts.put(parts[0], currentfreq + Integer.valueOf(parts[1]) );
		 			}else{
		 				DScounts.put(parts[0], Integer.valueOf(parts[1]) );
		 			}
		 			//endwhile
		 		}
		 		
		 	// now get the DS with maximum number of hits, #hits for that DS, total #hits  		
		 		maxfreq = -1;
		 		totfreq =  0;
		 		maxDS   = "";
		 		Iterator<String> DSitr = DScounts.keySet().iterator();
				
				while (DSitr.hasNext()) {
					currentDS = DSitr.next();
					currentfreq = DScounts.get(currentDS);
					
					if (maxfreq < currentfreq) {
						maxfreq = currentfreq;
						maxDS = currentDS;
					}
					totfreq += currentfreq;
				}
			
			// repeat to get DS with second highest #hits	
		 		maxfreq2 = -1;
		 		maxDS2   = "NaN";
		 	// first erase maxDS
		 		DScounts.put(maxDS, 0);
		 		DSitr = DScounts.keySet().iterator();
				
				while (DSitr.hasNext()) {
					currentDS = DSitr.next();
					currentfreq = DScounts.get(currentDS);
					
					if (maxfreq2 < currentfreq) {
						maxfreq2 = currentfreq;
						maxDS2 = currentDS;
					}
				}
				if(maxfreq2==0){
					maxDS2="NaN";
				}
		 		
		 		output.collect(key, new Text(maxDS + "," + String.valueOf(maxfreq) + "," + maxDS2 + "," + String.valueOf(maxfreq2) + "," + String.valueOf(totfreq)));	
				
		  //endreduce
		 }
	}

	public static void main(String[] args) throws Exception {
		JobConf conf = new JobConf(WorkHomeTowerMonthlyCombine.class);
		conf.setJobName("WorkHomeTowerMonthlyCombine");
		conf.setNumReduceTasks(3);

		conf.setOutputKeyClass(Text.class);
		conf.setOutputValueClass(Text.class);
		conf.setMapperClass(Map.class);
		//conf.setCombinerClass(Reduce.class);
		conf.setReducerClass(Reduce.class);

		conf.setInputFormat(TextInputFormat.class);
		conf.setOutputFormat(TextOutputFormat.class);

		FileInputFormat.setInputPaths(conf, new Path(args[0]));
		FileOutputFormat.setOutputPath(conf, new Path(args[1]));

		JobClient.runJob(conf);
	}
}