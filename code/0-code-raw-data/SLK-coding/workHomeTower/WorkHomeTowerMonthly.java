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

import utilities.PublicHolidaycsvReader;
import utilities.TowerCsvReader;


/**
 * This Hadoop class will take raw Voice data from company A as input along with the start, end times of
 * Work, Home (precision: 1 minute) and give out the frequencies of each key
 * Program Arguments: <in> <out> 
 * 
 * Example input line: 1|NOKIA1000, 1282|651004263|865545701|40619|20130101102734|20|LOCAL
 * Description: Direction | Phone name | Party A | Party B | Call ID | DateTimeString | Duration | Local/International
 * 
 * Example output line: 651004263,19781        5
 * Description: ID, Home/Work (0=home) <-Tab-> Tower ID, Frequency
 * 
 * @author Gabriel Kreindler
 * 
 */

public class WorkHomeTowerMonthly {

	public static class Map extends MapReduceBase implements
			Mapper<LongWritable, Text, Text, Text> {
		    private String ID,hw,Tower;
		    private Integer hour, day, month, year, date;
		    TowerCsvReader Towerlist = new TowerCsvReader();
		    PublicHolidaycsvReader pdays = new PublicHolidaycsvReader();
		 	
		 	public void map(LongWritable key, Text value, OutputCollector<Text, Text> output, Reporter reporter) throws IOException {
		 		String line = value.toString();
				String[] parts=line.split("\\|");
				
				// get ID depending on direction of call
				if(parts[0].equals("1")){
					ID=parts[3];
				}
				else if(parts[0].equals("2")){
					ID=parts[2];
				}
				
				// Get DS associated with cell tower id = parts[4]
				if( Towerlist.getTowerID(parts[4]) != null ){
					
					Tower = Towerlist.getTowerID(parts[4]);	
				
					// output if time is between 21:00 and 05:00  <-- Home
					// output if time is between 10:00 and 15:00  <-- Work, not weekends nor 14 and 25 jan
					year   = Integer.valueOf(parts[5].substring(0,  4));
					month  = Integer.valueOf(parts[5].substring(4,  6));
					day    = Integer.valueOf(parts[5].substring(6,  8));
					date   = Integer.valueOf(parts[5].substring(2,  8));
					hour   = Integer.valueOf(parts[5].substring(8, 12));
					
					// day of the week: Sunday=1 and Saturday=7
					Calendar c = Calendar.getInstance();
					c.set(year-1900, month, day);
					int dayOfWeek = c.get(Calendar.DAY_OF_WEEK);
					
					// work
				    if( hour > 1000 && hour <= 1500 && !pdays.dayset.contains(date) && dayOfWeek!=1 && dayOfWeek!=7){ 
				    	hw = "1"; 
				    	// ID = key + work (1)
				    	// value = day + DScode
				    	output.collect( new Text(ID + "," + hw) , new Text(date + "," + Tower ) );
					}
				    // home
				    else if(hour < 500 || hour >= 2100){   // if in home interval
				    	hw = "0";
				    	
				    	// set previous day - minor exception for 1st of the month
				    	if(hour < 500 & day>1) date--;
				    		
				    	// ID = key + home (0)
				    	// value = day + DScode
				    	output.collect( new Text(ID + "," + hw) , new Text(date + "," + Tower ) );
				    }
				    
			    //if DS exists
				}
				
			// end map	
		 	 }
	}

	public static class Reduce extends MapReduceBase implements Reducer<Text, Text, Text, Text> {
		private String line;
			public void reduce(Text key, Iterator<Text> values, OutputCollector<Text, Text> output, Reporter reporter) throws IOException {
				
				HashSet<String> DSdateSet = new HashSet<String>(); // keep track of calls from the same DS,day
				HashMap<String, Integer> DScounts = new HashMap<String, Integer>(); //stores DS + #hits
				int temp, currentfreq;
				String DS, currentDS;

		 		while (values.hasNext()) {
		 			line = values.next().toString();
		 			
		 			if(!DSdateSet.contains(line)){ // if we haven't already read this DS + date combination
		 			
		 				DSdateSet.add(line); // add it to hashset
		 				String[] parts = line.split(","); // date + DS ID
		 				
		 				DS = parts[1];
		 				
		 				if( DScounts.containsKey(DS) ){ // increment the number of hits of that DS

		 					temp = DScounts.get(DS); 
		 					//DScounts.remove(DS);
		 					DScounts.put(DS, temp+1);
		 					
		 				}else{ 								// if first time, initialize
		 					DScounts.put(DS, 1);
		 				}
		 			// endif	
		 			}
		 			//endwhile
		 		}
		 		
		 		// now output all (DS, frequency) combinations 	 		
		 		Iterator<String> DSitr = DScounts.keySet().iterator();
				
				while (DSitr.hasNext()) {
					currentDS = DSitr.next();
					currentfreq = DScounts.get(currentDS);
					
					output.collect(key, new Text( currentDS + "," + String.valueOf(currentfreq)));	
				}
		 		
		  //endreduce
		 }
	}

	public static void main(String[] args) throws Exception {
		JobConf conf = new JobConf(WorkHomeTowerMonthly.class);
		conf.setJobName("WorkHomeTower");
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